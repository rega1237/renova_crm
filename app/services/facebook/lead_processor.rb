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

    fields.each do |field|
      case field["name"]
      when "full_name" then mapped_attributes[:name] = field["values"].first
      when "email" then mapped_attributes[:email] = field["values"].first
      when "phone_number" then mapped_attributes[:phone] = field["values"].first
      when "street_address" then mapped_attributes[:address] = field["values"].first
      when "zip_code" then mapped_attributes[:zip_code] = field["values"].first
      when "state"
        mapped_attributes[:state_id] = find_state_for_facebook(field["values"].first)&.id
      end
    end
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

    # 1) Buscar por abreviación exacta (case-insensitive)
    state = State.where("LOWER(abbreviation) = ?", v_down).first

    # 2) Buscar por nombre exacto (case-insensitive)
    state ||= State.where("LOWER(name) = ?", v_down).first

    # 3) Fallback por prefijo en nombre (para typos frecuentes como "texa" -> "Texas")
    state ||= State.where("LOWER(name) LIKE ?", "#{v_down}%").first

    state
  end
end
