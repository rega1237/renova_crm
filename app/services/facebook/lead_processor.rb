class Facebook::LeadProcessor
  def initialize(lead_id:)
    @lead_id = lead_id
    integration = FacebookIntegration.first
    raise "No se ha configurado la integración con Facebook." unless integration&.access_token
    @graph = Koala::Facebook::API.new(integration.access_token)
  end

  def process
    lead_data = fetch_lead_data
    return unless lead_data

    client_attributes = map_fields(lead_data["field_data"])

    existing_client = Client.find_by(email: client_attributes[:email])

    if existing_client
      # Intentar actualizar ubicación según nuevos datos del lead sin degradar información confiable
      begin
        new_state_id = client_attributes[:state_id]
        new_city_id  = client_attributes[:city_id]
        new_zip      = client_attributes[:zip_code]

        update_attrs = {}

        # Actualizar estado si viene y no es un downgrade a 'Otro' teniendo ya un estado específico
        if new_state_id.present?
          candidate_state = State.find_by(id: new_state_id)
          keep_existing_state = existing_client.state && existing_client.state.name.to_s.downcase != "otro"
          is_new_state_otro  = candidate_state && candidate_state.name.to_s.downcase == "otro"
          if existing_client.state_id.blank? || (!is_new_state_otro || !keep_existing_state)
            update_attrs[:state_id] = new_state_id if existing_client.state_id != new_state_id
          end
        end

        # Actualizar ciudad si viene y no es un downgrade a 'Otro' teniendo ya una ciudad específica
        if new_city_id.present?
          candidate_city = City.find_by(id: new_city_id)
          keep_existing_city = existing_client.city && existing_client.city.name.to_s.downcase != "otro"
          is_new_city_otro   = candidate_city && candidate_city.name.to_s.downcase == "otro"
          if existing_client.city_id.blank? || (!is_new_city_otro || !keep_existing_city)
            update_attrs[:city_id] = new_city_id if existing_client.city_id != new_city_id
          end
        end

        # Actualizar ZIP solo si viene y es válido para la ciudad final (nueva o existente)
        if new_zip.present?
          target_city_id = update_attrs[:city_id] || existing_client.city_id
          if target_city_id.present?
            if Zipcode.where(city_id: target_city_id).where("code LIKE ?", "#{new_zip}%").exists?
              update_attrs[:zip_code] = new_zip if existing_client.zip_code != new_zip
            end
          end
        end

        existing_client.update!(update_attrs) if update_attrs.any?
      rescue => e
        # No romper el flujo si algo falla al ajustar ubicación
      end

      reentry_time_val = lead_data["created_time"]
      reentry_time =
        case reentry_time_val
        when Integer
          Time.zone.at(reentry_time_val)
        when String
          reentry_time_val.present? ? Time.zone.parse(reentry_time_val) : Time.current
        else
          Time.current
        end
      old_status = existing_client.status

      # 1) Si no es lead, mover a lead
      if existing_client.status != "lead"
        existing_client.update!(status: :lead)
      end

      # 2) Actualizar la fecha de creación para que aparezca primero en la columna de leads
      existing_client.update_columns(created_at: reentry_time)

      # 3) Agregar nota automática del reingreso por publicidad
      note_creator = Current.user || existing_client.updated_by || User.first
      Note.create!(
        client: existing_client,
        created_by: note_creator,
        text: "Cliente volvió a entrar por publicidad el #{reentry_time.strftime('%d/%m/%Y a las %H:%M')}"
      )

      # 4) Broadcast al Sales Flow para actualizar la tarjeta y mostrar notificación
      client_html = ApplicationController.render(
        partial: "sales_flow/client_card",
        locals: { client: existing_client }
      )

      ActionCable.server.broadcast(
        "sales_flow_channel",
        {
          action: "client_moved",
          client_id: existing_client.id,
          client_name: existing_client.name,
          updated_by_name: Current.user&.name || "Sistema",
          old_status: old_status,
          new_status: "lead",
          reentered: true,
          client_html: client_html
        }
      )

      return
    end

    # 1. Creamos el cliente y lo guardamos en una variable
    new_client = Client.new(client_attributes)

    if new_client.save
      puts "¡Nuevo cliente '#{new_client.name}' creado exitosamente!"

      # 2. Renderizamos el HTML de la tarjeta del cliente
      client_html = ApplicationController.render(
        partial: "sales_flow/client_card",
        locals: { client: new_client }
      )

      # 3. Hacemos el broadcast por Action Cable
      ActionCable.server.broadcast(
        "sales_flow_channel",
        {
          action: "new_lead_created", # Una acción nueva y específica
          client_name: new_client.name,
          client_html: client_html
        }
      )
    else
      puts "Error al crear el cliente: #{new_client.errors.full_messages.join(', ')}"
    end

  rescue Koala::Facebook::APIError => e
    puts "Error de la API de Facebook: #{e.message}"
  end

  private

  def fetch_lead_data
    @graph.get_object(@lead_id)
  end

  def map_fields(fields)
    # El valor por defecto para un nuevo lead de Meta debe ser 'lead'
    mapped_attributes = { source: :meta, status: :lead }

    # Capturar entradas crudas para resolver ubicación jerárquica al final
    input_state = nil
    input_city = nil
    input_zip = nil

    fields.each do |field|
      case field["name"]
      when "full_name" then mapped_attributes[:name] = field["values"].first
      when "email" then mapped_attributes[:email] = field["values"].first
      when "phone_number" then mapped_attributes[:phone] = field["values"].first
      when "street_address" then mapped_attributes[:address] = field["values"].first
      when "zip_code" then input_zip = field["values"].first
      when "state" then input_state = field["values"].first
      when "city" then input_city = field["values"].first
      end
    end

    # Resolver state -> city -> zipcode según reglas definidas
    resolved = resolve_location_with_hierarchy(state_input: input_state, city_input: input_city, zip_input: input_zip)
    mapped_attributes[:state_id] = resolved[:state]&.id
    mapped_attributes[:city_id]  = resolved[:city]&.id
    mapped_attributes[:zip_code] = resolved[:zip]

    mapped_attributes
  end

  # Buscar estado por valor proveniente de Facebook.
  # Intenta por abreviación (TX), por nombre exacto (Texas) y finalmente por coincidencia de prefijo ("texa" -> "Texas").
  def find_state_for_facebook(value)
    v = value.to_s.strip
    return nil if v.blank?

    # Normalizar: eliminar acentos y espacios extras
    v_norm = I18n.transliterate(v).strip
    v_down = v_norm.downcase

    # Variante que elimina dígitos y símbolos (caso "Texas77026", "TX-77026")
    v_alpha = v_norm.gsub(/[^a-zA-Z ]/, " ").squeeze(" ").strip
    v_alpha_down = v_alpha.downcase

    # 1) Buscar por abreviación exacta (case-insensitive)
    state = State.where("LOWER(abbreviation) = ?", v_down).first
    state ||= State.where("LOWER(abbreviation) = ?", v_alpha_down).first

    # 2) Buscar por nombre exacto (case-insensitive)
    state ||= State.where("LOWER(name) = ?", v_down).first
    state ||= State.where("LOWER(name) = ?", v_alpha_down).first

    # 3) Fallback por prefijo en nombre (para typos frecuentes como "texa" -> "Texas")
    state ||= State.where("LOWER(name) LIKE ?", "#{v_down}%").first
    state ||= State.where("LOWER(name) LIKE ?", "#{v_alpha_down}%").first

    state
  end

  # Asegurar la existencia del estado 'Otro' y retornarlo
  def ensure_other_state
    State.where("LOWER(name) = ?", "otro").first || State.find_or_create_by(name: "Otro") do |s|
      s.abbreviation = "OTRO"
    end
  rescue => e
    # Si no se puede asegurar, no romper el flujo
    nil
  end

  # Garantiza o retorna la City 'Otro' asociada al estado dado
  def ensure_other_city(state)
    return nil if state.nil?
    City.where(state: state).where("LOWER(name) = ?", "otro").first || City.find_or_create_by(state: state, name: "Otro")
  rescue => e
    nil
  end

  # Buscar ciudad por nombre dentro de un estado (case-insensitive)
  def find_city_by_name_and_state(name, state)
    n = name.to_s.strip
    return nil if n.blank? || state.nil?
    n_norm = I18n.transliterate(n).strip
    n_alpha = n_norm.gsub(/[^a-zA-Z ]/, " ").squeeze(" ").strip
    City.where(state: state).where("LOWER(name) = ?", n_norm.downcase).first ||
      City.where(state: state).where("LOWER(name) = ?", n_alpha.downcase).first
  end

  # Buscar ciudad por nombre sin importar el estado (case-insensitive)
  def find_city_global(name)
    n = name.to_s.strip
    return nil if n.blank?
    n_norm = I18n.transliterate(n).strip
    n_alpha = n_norm.gsub(/[^a-zA-Z ]/, " ").squeeze(" ").strip
    City.where("LOWER(name) = ?", n_norm.downcase).first ||
      City.where("LOWER(name) = ?", n_alpha.downcase).first
  end

  # Normaliza zip_code a formato de 5 dígitos (US). Acepta ZIP+4 (ej. 12345-6789) y devuelve 12345.
  def normalize_zip_code(value)
    v = value.to_s.strip
    return nil if v.blank?
    if v =~ /(\d{5})(?:-\d{4})?/
      $1
    else
      m = v.scan(/\d{5}/).last
      m
    end
  end

  # Busca un Zipcode por code; acepta 5 dígitos y ZIP+4 (se usa 5 dígitos base para la búsqueda)
  def find_zipcode_by_code(code)
    five = normalize_zip_code(code)
    return nil if five.blank?
    Zipcode.where(code: five).first || Zipcode.where("code LIKE ?", "#{five}%").first
  end

  # Resuelve la ubicación completa aplicando reglas jerárquicas y de consistencia
  # Retorna hash: { state: State|nil, city: City|nil, zip: String|nil }
  def resolve_location_with_hierarchy(state_input:, city_input:, zip_input:)
    zip_norm = normalize_zip_code(zip_input)
    state = nil
    city = nil
    zip_str = nil

    # Heurística: muchos leads de Meta llegan con city/state invertidos (ej. state = "Austin", city = "Texas").
    # Si detectamos que el valor de state parece una ciudad y el valor de city parece un estado, los intercambiamos.
    if state_input.present? && city_input.present?
      looks_like_state_in_city = find_state_for_facebook(city_input).present?
      looks_like_city_in_state = find_city_global(state_input).present?
      looks_like_state_in_state = find_state_for_facebook(state_input).present?

      if !looks_like_state_in_state && looks_like_state_in_city && looks_like_city_in_state
        # Intercambiar
        Rails.logger.info("[LeadProcessor] Detectada inversión de city/state. Swapping: state='#{state_input}' <-> city='#{city_input}'") rescue nil
        state_input, city_input = city_input, state_input
      end
    end

    if state_input.present?
      state = find_state_for_facebook(state_input) || ensure_other_state
      if city_input.present?
        candidate_city = find_city_by_name_and_state(city_input, state)
        if candidate_city
          city = candidate_city
          if zip_norm.present?
            zr = find_zipcode_by_code(zip_norm)
            if zr && zr.city_id == city.id
              zip_str = normalize_zip_code(zr.code)
            else
              # Mismatch: mantener city existente bajo el estado y dejar zip en blanco
              # Preferir derivación por ZIP si el estado es 'Otro' (confianza baja)
              if zr && state&.name.to_s.downcase == "otro"
                city = zr.city
                state = city.state
                zip_str = normalize_zip_code(zr.code)
              else
                zip_str = nil
              end
            end
          end
        else
          # City no existe bajo el estado
          if zip_norm.present?
            zr = find_zipcode_by_code(zip_norm)
            if zr && zr.city.state_id == state.id
              city = zr.city
              zip_str = normalize_zip_code(zr.code)
            else
              # Si el estado es 'Otro' pero el ZIP es válido, derivar todo por ZIP
              if zr
                city = zr.city
                state = city.state if state&.name.to_s.downcase == "otro"
                zip_str = normalize_zip_code(zr.code)
              else
                city = ensure_other_city(state)
                zip_str = nil
              end
            end
          else
            city = ensure_other_city(state)
          end
        end
      else
        # Sin city, intentar por ZIP
        if zip_norm.present?
          zr = find_zipcode_by_code(zip_norm)
          if zr && zr.city.state_id == state.id
            city = zr.city
            zip_str = normalize_zip_code(zr.code)
          else
            city = ensure_other_city(state)
            zip_str = nil
          end
        else
          city = ensure_other_city(state)
        end
      end
    elsif city_input.present?
      # Derivar state por city
      cg = find_city_global(city_input)
      if cg
        city = cg
        state = cg.state
        if zip_norm.present?
          zr = find_zipcode_by_code(zip_norm)
          if zr && zr.city_id == city.id
            zip_str = normalize_zip_code(zr.code)
          else
            # Mismatch: mantener city derivada y dejar zip en blanco
            zip_str = nil
          end
        end
      else
        # City no existe; intentar derivar por ZIP
        if zip_norm.present?
          zr = find_zipcode_by_code(zip_norm)
          if zr
            city = zr.city
            state = city.state
            zip_str = normalize_zip_code(zr.code)
          end
        end
        # Si no hay ZIP válido, dejar sin state/city (usuario no dio info consistente)
      end
    elsif zip_norm.present?
      # Sin state ni city: derivar todo por ZIP
      zr = find_zipcode_by_code(zip_norm)
      if zr
        city = zr.city
        state = city.state
        zip_str = normalize_zip_code(zr.code)
      else
        # ZIP desconocido: usar 'Otro' para state y city y dejar zip en blanco
        state = ensure_other_state
        city = ensure_other_city(state)
        zip_str = nil
      end
    end

    { state: state, city: city, zip: zip_str }
  end
end
