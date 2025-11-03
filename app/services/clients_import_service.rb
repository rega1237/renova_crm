# frozen_string_literal: true

require "roo"
require "roo-xls"

class ClientsImportService
  Result = Struct.new(
    :total_rows,
    :imported_clients_count,
    :updated_clients_count,
    :notes_created_count,
    :warnings,
    :errors,
    keyword_init: true
  )

  def initialize(file, current_user:)
    @file = file
    @current_user = current_user
    @result = Result.new(
      total_rows: 0,
      imported_clients_count: 0,
      updated_clients_count: 0,
      notes_created_count: 0,
      warnings: [],
      errors: []
    )
    @placeholder_user = ensure_placeholder_user
  end

  attr_reader :result

  # update_existing: si true, actualiza clientes existentes por teléfono; si false, siempre crea nuevos
  def call(update_existing: false)
    unless valid_extension?(@file)
      raise "Formato de archivo no soportado. Usa .xlsx o .xls"
    end

    xls = open_spreadsheet(@file)

    xls.sheets.each do |sheet_name|
      sheet = xls.sheet(sheet_name)
      headers = normalize_headers(Array(sheet.row(1)))
      last_row = sheet.last_row.to_i
      next if last_row < 2

      (2..last_row).each do |row_index|
        row_values = Array(sheet.row(row_index))
        row = headers.zip(row_values).to_h
        @result.total_rows += 1
        import_row(row, update_existing)
      rescue => e
        @result.errors << "Hoja #{sheet_name} fila #{row_index}: #{e.message}"
      end
    end

    @result
  end

  # Versión con reporte de progreso en tiempo real.
  # on_progress: ->(payload_hash) { ... }
  def call_with_progress(update_existing: false, on_progress: nil)
    unless valid_extension?(@file)
      raise "Formato de archivo no soportado. Usa .xlsx o .xls"
    end

    xls = open_spreadsheet(@file)

    # Calcular total de filas por adelantado
    total_rows = 0
    xls.sheets.each do |sheet_name|
      sheet = xls.sheet(sheet_name)
      last_row = sheet.last_row.to_i
      total_rows += [last_row - 1, 0].max
    end
    on_progress&.call(event: "start", message: "Procesando #{total_rows} filas de clientes", total: total_rows, processed: 0, percent: 0)

    processed = 0
    xls.sheets.each do |sheet_name|
      sheet = xls.sheet(sheet_name)
      headers = normalize_headers(Array(sheet.row(1)))
      last_row = sheet.last_row.to_i
      next if last_row < 2

      (2..last_row).each do |row_index|
        row_values = Array(sheet.row(row_index))
        row = headers.zip(row_values).to_h
        @result.total_rows += 1
        import_row(row, update_existing)
        processed += 1
        pct = total_rows > 0 ? (processed * 100 / total_rows) : 0
        on_progress&.call(event: "tick", total: total_rows, processed: processed, percent: pct, message: "Fila #{processed}/#{total_rows}")
      rescue => e
        @result.errors << "Hoja #{sheet_name} fila #{row_index}: #{e.message}"
        on_progress&.call(event: "error", message: "Hoja #{sheet_name} fila #{row_index}: #{e.message}")
      end
    end

    @result
  end

  private

  def ensure_placeholder_user
    User.find_or_create_by(email: "telemarketing_placeholder@example.com") do |u|
      u.name = "Telemarketing Placeholder"
      u.password = SecureRandom.hex(12)
      u.rol = :telemarketing
    end
  end

  def valid_extension?(file)
    filename = (file.respond_to?(:original_filename) ? file.original_filename : File.basename(file.to_s)).to_s
    ext = File.extname(filename).downcase
    %w[.xlsx .xls].include?(ext)
  end

  def open_spreadsheet(file)
    path = if file.respond_to?(:path)
      file.path
    elsif file.respond_to?(:tempfile)
      file.tempfile.path
    else
      file.to_s
    end
    Roo::Spreadsheet.open(path)
  end

  def normalize_headers(headers)
    headers.map do |h|
      normalize_key(h)
    end
  end

  def normalize_key(key)
    str = key.to_s.strip
    str = I18n.transliterate(str)
    str.downcase.gsub(/[\s\-]+/, "_")
  end

  def import_row(row, update_existing)
    phone_raw = row["phone"].to_s
    phone = normalize_phone(phone_raw)
    if phone.blank?
      phone = "123456"
    end

    created_at_client = parse_excel_datetime(row["created_at"]) || Time.current

    name = row["name"].to_s.strip
    last_name = row["last_name"].to_s.strip
    full_name = [ name, last_name ].reject(&:blank?).join(" ")
    if full_name.blank?
      full_name = "Sin nombre"
    end

    address = row["address"].to_s.strip
    state_value = row["state"].to_s.strip
    city_value = row["city"].to_s.strip
    zip_value = row["zip_code"].to_s.strip

    # Resolver estado según Excel; si no existe, asegurar 'Otro' pero recordar si el Excel realmente lo proporcionó
    state_from_excel = find_state(state_value)
    excel_state_provided = state_from_excel.present?
    state = state_from_excel
    if state.nil?
      if state_value.blank?
        @result.warnings << "Estado vacío, se asigna 'Otro' (tel #{phone})"
      else
        @result.warnings << "Estado no encontrado: '#{state_value}' (tel #{phone}), se asigna 'Otro'"
      end
      state = ensure_other_state
    end

    # Determinar ZIP: primero columna zip_code; si no, intentar extraer de address
    normalized_zip_from_excel = normalize_zip_code(zip_value)
    normalized_zip_from_address = normalized_zip_from_excel.present? ? nil : extract_zip_from_address(address)
    normalized_zip = normalized_zip_from_excel.presence || normalized_zip_from_address.presence
    # Guardaremos en el cliente el zip_code en formato 5 dígitos cuando corresponda
    client_zip_string = nil

    # Determinar city en base a reglas confirmadas
    city = nil
    if normalized_zip.present?
      zip_record = find_zipcode_by_code(normalized_zip)
      if zip_record
        zip_state = zip_record.city.state
        zip_city = zip_record.city

        # Si Excel realmente trajo un estado y difiere del ZIP, priorizar estado del Excel y usar city/zip 'Otro' para ese estado
        if excel_state_provided && state && zip_state && zip_state.id != state.id
          @result.warnings << "ZIP #{normalized_zip} pertenece a '#{zip_state.name}', pero Excel indica estado '#{state.name}'. Se usa estado del Excel y city/zipcode 'Otro'. (tel #{phone})"
          city = ensure_other_city(state)
          ensure_other_zipcode(city) # Garantizar existencia
          # En caso de conflicto, no establecer zip_code del cliente para evitar incongruencias
          client_zip_string = nil
        else
          # Sin conflicto o sin estado Excel: usar estado/city del ZIP
          state = zip_state
          city = zip_city
          client_zip_string = normalize_zip_code(zip_record.code)
        end
      else
        # ZIP provisto o extraído pero no existe en BD
        if state
          @result.warnings << "ZIP #{normalized_zip} no encontrado en BD; se asigna city/zipcode 'Otro' bajo el estado '#{state.name}'. (tel #{phone})"
          city = ensure_other_city(state)
          ensure_other_zipcode(city)
          # Aunque el ZIP no exista en BD, si vino en el archivo o se extrajo del address, guardarlo como texto para referencia
          client_zip_string = normalized_zip
        else
          # No hay estado válido, todo 'Otro'
          state = ensure_other_state
          city = ensure_other_city(state)
          ensure_other_zipcode(city)
          client_zip_string = normalized_zip
        end
      end
    else
      # No hay ZIP disponible: respetar city del Excel si existe dentro del state
      if state
        if city_value.present?
          found_city = find_city_by_name_and_state(city_value, state)
          if found_city
            city = found_city
          else
            @result.warnings << "Ciudad '#{city_value}' no encontrada en estado '#{state.name}'; se asigna 'Otro'. (tel #{phone})"
            city = ensure_other_city(state)
          end
        else
          city = ensure_other_city(state)
        end
        ensure_other_zipcode(city) # Garantizar existencia de zipcode 'Otro' para esa city
      else
        # Sin estado válido
        state = ensure_other_state
        city = ensure_other_city(state)
        ensure_other_zipcode(city)
      end
    end

    status_value = row["status"].to_s
    status_mapped = map_status(status_value)
    if status_value.present? && status_mapped == "lead" && normalize_status(status_value) != "lead"
      @result.warnings << "Status desconocido '#{status_value}', se asigna 'lead' (tel #{phone})"
    elsif status_value.blank?
      status_mapped = "lead"
    end

    source_value = row["source"].to_s
    source_mapped = map_source(source_value)
    if source_value.present? && source_mapped == "otro" && normalize_source(source_value) != "otro"
      @result.warnings << "Fuente desconocida '#{source_value}', se asigna 'otro' (tel #{phone})"
    end
    source_final = source_mapped || "base_de_datos"

    client_attrs = {
      name: full_name,
      phone: phone,
      address: address,
      state: state,
      city: city,
      zip_code: client_zip_string,
      status: status_mapped,
      source: source_final
    }

    client = if update_existing
      Client.find_or_initialize_by(phone: phone)
    else
      Client.new
    end

    client.assign_attributes(client_attrs)

    # Establecer fechas según el estado del cliente
    if client.new_record?
      # Para clientes nuevos, siempre establecer created_at
      client.created_at = created_at_client

      # Si el estado no es 'lead', también establecer updated_status_at
      if status_mapped != "lead"
        client.updated_status_at = created_at_client
      end
    else
      # Para clientes existentes que se están actualizando
      # Si el estado cambió y no es 'lead', actualizar updated_status_at
      if client.status_changed? && status_mapped != "lead"
        client.updated_status_at = created_at_client
      end
    end

    if client.save
      # Contabilizar antes de cualquier actualización directa de columnas
      if update_existing && !client.previous_changes.empty?
        @result.updated_clients_count += 1
      elsif client.previous_changes.key?("id")
        @result.imported_clients_count += 1
      end

      # Para mantener compatibilidad con búsquedas y pruebas:
      # - Si el teléfono venía con '+', preservar E.164 tal cual
      # - Si no tenía '+', forzar almacenamiento como solo dígitos
      begin
        unless phone.to_s.start_with?("+")
          client.update_columns(phone: phone)
        end
      rescue StandardError
        # No impedir el flujo si falla el ajuste de columnas sin validación
      end

      create_notes_for_row(client, row)
    else
      @result.errors << "Cliente (tel #{phone}) no guardado: #{client.errors.full_messages.join(", ")}"
    end
  end

  def normalize_phone(phone)
    s = phone.to_s.strip
    return nil if s.blank?
    # Si ya viene en formato internacional, preservar tal cual (limpiando espacios)
    if s.start_with?("+")
      return s.gsub(/\s+/, "")
    end
    # Para importaciones sin '+', conservar solo dígitos para que las búsquedas
    # por el valor del archivo funcionen tal cual (compatibilidad con pruebas)
    digits = s.gsub(/[^0-9]/, "")
    digits.presence
  end

  def find_state(value)
    v = value.to_s.strip
    return nil if v.blank?

    # Buscar por abreviación (TX, IL) o por nombre (Texas, Illinois) - case-insensitive
    State.where("LOWER(abbreviation) = ?", v.downcase).first || State.where("LOWER(name) = ?", v.downcase).first
  end

  # Busca o crea (de forma segura) el estado "Otro" y lo retorna
  def ensure_other_state
    State.where("LOWER(name) = ?", "otro").first || State.find_or_create_by(name: "Otro") do |s|
      # Abreviación requerida por validaciones del modelo State
      s.abbreviation = "OTRO"
    end
  rescue => e
    @result.errors << "No se pudo asegurar estado 'Otro': #{e.message}"
    nil
  end

  # Garantiza o retorna la City 'Otro' asociada al estado dado
  def ensure_other_city(state)
    return nil if state.nil?
    City.where(state: state).where("LOWER(name) = ?", "otro").first || City.find_or_create_by(state: state, name: "Otro")
  rescue => e
    @result.errors << "No se pudo asegurar city 'Otro' para estado '#{state&.name}': #{e.message}"
    nil
  end

  # Garantiza o retorna el Zipcode 'Otro' para la ciudad dada
  def ensure_other_zipcode(city)
    return nil if city.nil?
    Zipcode.where(city: city).where("LOWER(code) = ?", "otro").first || Zipcode.find_or_create_by(city: city, code: "Otro")
  rescue => e
    @result.errors << "No se pudo asegurar zipcode 'Otro' para ciudad '#{city&.name}': #{e.message}"
    nil
  end

  # Buscar ciudad por nombre dentro de un estado (case-insensitive)
  def find_city_by_name_and_state(name, state)
    n = name.to_s.strip
    return nil if n.blank? || state.nil?
    City.where(state: state).where("LOWER(name) = ?", n.downcase).first
  end

  # Normaliza zip_code a formato de 5 dígitos (US). Acepta ZIP+4 (ej. 12345-6789) y devuelve 12345.
  def normalize_zip_code(value)
    v = value.to_s.strip
    return nil if v.blank?
    # Buscar primera ocurrencia de 5 dígitos consecutivos
    if v =~ /(\d{5})(?:-\d{4})?/
      $1
    else
      # Tomar la última secuencia de 5 dígitos si existiera
      m = v.scan(/\d{5}/).last
      m
    end
  end

  # Extrae ZIP (5 dígitos) desde el address. Soporta ZIP+4; prioriza última aparición en el texto.
  def extract_zip_from_address(address)
    str = address.to_s
    return nil if str.blank?
    # Generalmente el ZIP está al final; usar última coincidencia
    m = str.scan(/(\d{5})(?:-\d{4})?/).last
    m ? m.first : nil
  end

  # Busca un Zipcode por code; acepta 5 dígitos y ZIP+4 (se usa 5 dígitos base para la búsqueda)
  def find_zipcode_by_code(code)
    five = normalize_zip_code(code)
    return nil if five.blank?
    # Preferir match exacto; luego ZIP+4 (LIKE '12345%')
    Zipcode.where(code: five).first || Zipcode.where("code LIKE ?", "#{five}%").first
  end

  def map_status(value)
    norm = normalize_status(value)
    allowed = %w[lead no_contesto seguimiento cita_agendada reprogramar vendido mal_credito no_cerro no_aplica_no_interesado]
    if allowed.include?(norm)
      norm
    else
      # Intentar variantes comunes
      case norm
      when "no_contesto"
        "no_contesto"
      when "citaagendada"
        "cita_agendada"
      when "malcredito"
        "mal_credito"
      when "nocerro"
        "no_cerro"
      when "noaplica", "no_aplica", "nointeresado", "no_interesado", "no_aplica_no_interesado"
        "no_aplica_no_interesado"
      else
        "lead"
      end
    end
  end

  def normalize_status(value)
    s = value.to_s.strip
    return "lead" if s.blank?
    s = I18n.transliterate(s)
    s.downcase.gsub(/[^a-z0-9]+/, "_").gsub(/_{2,}/, "_").gsub(/^_|_$/, "")
  end

  def map_source(value)
    norm = normalize_source(value)
    return nil if norm.blank?

    allowed = Client.sources.keys
    return norm if allowed.include?(norm)

    case norm
    when "base", "basededatos", "base_datos", "base-de-datos", "bd"
      "base_de_datos"
    when "referencias", "referido", "referidos", "ref"
      "referencia"
    when "prospectacion", "prospectacion_", "prospecta", "prospect"
      "prospectacion"
    when "meta_ads", "metaads"
      "meta"
    when "otro", "otros"
      "otro"
    else
      # Si no coincide con nada conocido y venía algo, mapear a 'otro'
      "otro"
    end
  end

  def normalize_source(value)
    s = value.to_s.strip
    return "" if s.blank?
    s = I18n.transliterate(s)
    s.downcase.gsub(/[^a-z0-9]+/, "_").gsub(/_{2,}/, "_").gsub(/^_|_$/, "")
  end

  def create_notes_for_row(client, row)
    tz_name = client.timezone
    tz = ActiveSupport::TimeZone[tz_name] || Time.zone

    note_timestamp = parse_note_datetime(row["note_date"], row["note_hour"], tz)
    if note_timestamp.nil? && (row["note_date"].present? || row["note_hour"].present?)
      @result.warnings << "Fecha/hora de nota inválida (cliente #{client.phone})"
    end
    note_timestamp ||= client.created_at || Time.current

    # Detectar columnas dinámicas con prefijo note_text_
    note_columns = row.keys.select { |k| k.to_s.start_with?("note_text_") }

    note_columns.each do |col|
      text = row[col].to_s.strip
      next if text.blank?

      tm_name = col.to_s.sub("note_text_", "").strip
      tm_user = find_telemarketing_user(tm_name) || @placeholder_user

      note = client.notes.build(text: text, created_by: tm_user)
      note.created_at = note_timestamp
      if note.save
        @result.notes_created_count += 1
      else
        @result.errors << "Nota no guardada (cliente #{client.phone}): #{note.errors.full_messages.join(", ")}"
      end
    end
  end

  def find_telemarketing_user(name)
    n = name.to_s.strip
    return nil if n.blank?
    # Buscar por nombre (case-insensitive, substring) y rol telemarketing
    User.where(rol: :telemarketing).where("LOWER(name) LIKE ?", "%#{n.downcase}%").first
  end

  def parse_excel_datetime(value)
    case value
    when DateTime
      value.to_time
    when Date
      value.to_time
    when Time
      value
    when String
      begin
        Time.zone.parse(value)
      rescue
        nil
      end
    when Numeric
      # Alguns formatos Excel pueden llegar como numericos (dias desde un origen). Roo suele convertir, pero por si acaso.
      # Usar DateTime.jd si fuese serial tipo Excel? Por simplicidad, devolvemos nil.
      nil
    else
      nil
    end
  end

  def parse_note_datetime(date_value, time_value, tz)
    date_str = case date_value
    when DateTime
                 date_value.strftime("%Y-%m-%d")
    when Date
                 date_value.strftime("%Y-%m-%d")
    when String
                 begin
                   Date.parse(date_value).strftime("%Y-%m-%d")
                 rescue
                   nil
                 end
    else
                 nil
    end

    time_str = case time_value
    when Time
                 time_value.strftime("%H:%M")
    when DateTime
                 time_value.strftime("%H:%M")
    when String
                 parse_time_string(time_value)
    when Numeric
                 # Excel puede representar horas como fracción del día (ej: 0.5 -> 12:00)
                 seconds = (time_value.to_f * 24 * 3600).round
                 h = seconds / 3600
                 m = (seconds % 3600) / 60
                 format("%02d:%02d", h, m)
    else
                 nil
    end

    return nil if date_str.blank? || time_str.blank?

    begin
      tz.parse("#{date_str} #{time_str}")
    rescue
      nil
    end
  end

  def parse_time_string(str)
    s = str.to_s.strip
    return nil if s.blank?
    # Normalizar posibles formatos como "1:30 PM", "13:30", "13:30:00"
    begin
      t = Time.zone.parse(s)
      t.strftime("%H:%M")
    rescue
      # Intento simple de extraer HH:MM
      if s =~ /(\d{1,2}):(\d{2})/
        h = $1.to_i
        m = $2.to_i
        format("%02d:%02d", h, m)
      else
        nil
      end
    end
  end
end
