class LocationImportService
  Result = Struct.new(
    :rows_processed,
    :rows_failed,
    :states_created,
    :states_updated,
    :cities_created,
    :zipcodes_created,
    :zipcodes_existing,
    :errors,
    keyword_init: true
  )

  HEADER_MAP = {
    zip: "zip",
    primary_city: "primary_city",
    acceptable_cities: "acceptable_cities",
    state_abbreviation: "state_abbreviation",
    state_name: "state_name"
  }.freeze

  def initialize(file)
    @file = file
  end

  def call
    result = Result.new(
      rows_processed: 0,
      rows_failed: 0,
      states_created: 0,
      states_updated: 0,
      cities_created: 0,
      zipcodes_created: 0,
      zipcodes_existing: 0,
      errors: []
    )

    spreadsheet = open_spreadsheet(@file)
    headers = read_headers(spreadsheet)
    validate_headers!(headers)

    ((spreadsheet.first_row + 1)..spreadsheet.last_row).each do |row_index|
      row = read_row(spreadsheet, headers, row_index)
      begin
        ActiveRecord::Base.transaction do
          process_row(row, result)
        end
        result.rows_processed += 1
      rescue => e
        result.rows_failed += 1
        result.errors << { row: row_index, message: e.message }
      end
    end

    result
  end

  # Igual que call, pero reportando progreso mediante un callback opcional.
  # on_progress: ->(payload_hash) { ... }
  def call_with_progress(on_progress: nil)
    result = Result.new(
      rows_processed: 0,
      rows_failed: 0,
      states_created: 0,
      states_updated: 0,
      cities_created: 0,
      zipcodes_created: 0,
      zipcodes_existing: 0,
      errors: []
    )

    spreadsheet = open_spreadsheet(@file)
    headers = read_headers(spreadsheet)
    validate_headers!(headers)

    total_rows = (spreadsheet.last_row - spreadsheet.first_row).to_i
    on_progress&.call(event: "start", message: "Procesando #{total_rows} filas de ubicaciones", total: total_rows, processed: 0, percent: 0)

    processed = 0
    ((spreadsheet.first_row + 1)..spreadsheet.last_row).each do |row_index|
      row = read_row(spreadsheet, headers, row_index)
      begin
        ActiveRecord::Base.transaction do
          process_row(row, result)
        end
        result.rows_processed += 1
        processed += 1
        pct = total_rows > 0 ? (processed * 100 / total_rows) : 0
        on_progress&.call(event: "tick", total: total_rows, processed: processed, percent: pct, message: "Fila #{processed}/#{total_rows}")
      rescue => e
        result.rows_failed += 1
        result.errors << { row: row_index, message: e.message }
        on_progress&.call(event: "error", message: "Error en fila #{row_index}: #{e.message}")
      end
    end

    result
  end

  private

  def open_spreadsheet(file)
    require "roo"
    x = Roo::Spreadsheet.open(file.respond_to?(:path) ? file.path : file)
    x
  end

  def read_headers(sheet)
    sheet.row(sheet.first_row).map { |h| h.to_s.strip }
  end

  def validate_headers!(headers)
    expected = HEADER_MAP.values
    missing = expected - headers
    return if missing.empty?
    raise StandardError, "Faltan columnas en el Excel: #{missing.join(', ')}"
  end

  def read_row(sheet, headers, index)
    values = sheet.row(index)
    row_hash = {}
    headers.each_with_index do |header, i|
      row_hash[header] = values[i].to_s.strip
    end
    row_hash
  end

  def process_row(row, result)
    zip = row[HEADER_MAP[:zip]].presence
    primary_city_name = row[HEADER_MAP[:primary_city]].presence
    acceptable_cities_raw = row[HEADER_MAP[:acceptable_cities]].to_s
    state_abbr = row[HEADER_MAP[:state_abbreviation]].presence
    state_name = row[HEADER_MAP[:state_name]].presence

    raise StandardError, "Falta state_abbreviation o state_name" if state_abbr.blank? || state_name.blank?
    raise StandardError, "Falta primary_city" if primary_city_name.blank?
    raise StandardError, "Falta zip" if zip.blank?

    # Estado
    state = State.find_or_initialize_by(abbreviation: state_abbr)
    if state.new_record?
      state.name = state_name
      state.save!
      result.states_created += 1
    else
      if state.name != state_name
        state.update!(name: state_name)
        result.states_updated += 1
      end
    end

    # Ciudades: primaria + aceptables
    created_cities = []

    primary_city = find_or_create_city(primary_city_name, state, result)
    created_cities << primary_city

    acceptable_cities = parse_acceptable_cities(acceptable_cities_raw)
    acceptable_cities.each do |city_name|
      city = find_or_create_city(city_name, state, result)
      created_cities << city
    end

    # Zipcodes: asociar a ciudad primaria y a cada aceptable
    created_cities.uniq.each do |city|
      z = Zipcode.find_or_initialize_by(code: zip, city_id: city.id)
      if z.new_record?
        z.save!
        result.zipcodes_created += 1
      else
        result.zipcodes_existing += 1
      end

      # Fallback "Otro" para cada ciudad
      fallback = Zipcode.find_or_initialize_by(code: "Otro", city_id: city.id)
      fallback.save! if fallback.new_record?
    end
  end

  def parse_acceptable_cities(str)
    str.to_s.split(",").map { |c| c.strip }.select { |c| c.present? }
  end

  def find_or_create_city(name, state, result)
    city = City.find_or_initialize_by(name: name, state_id: state.id)
    if city.new_record?
      city.abbreviation = generate_city_abbreviation(name)
      city.save!
      result.cities_created += 1
    else
      # Asegurar abbreviation si está en blanco
      if city.abbreviation.blank?
        city.update!(abbreviation: generate_city_abbreviation(name))
      end
    end
    city
  end

  def generate_city_abbreviation(name)
    # Abreviación: primeras 3 letras de cada palabra, máximo 10 caracteres
    name.to_s.split(/[\s\-]+/).map { |w| w[0, 3] }.join.upcase[0, 10]
  end
end