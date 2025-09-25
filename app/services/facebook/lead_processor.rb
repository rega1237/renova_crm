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

    if Client.exists?(email: client_attributes[:email])
      puts "Cliente duplicado encontrado para el email: #{client_attributes[:email]}. Saltando..."
      return
    end

    Client.create!(client_attributes)
    puts "¡Nuevo cliente '#{client_attributes[:name]}' creado exitosamente!"
  rescue Koala::Facebook::APIError => e
    puts "Error de la API de Facebook: #{e.message}"
  end

  private

  def fetch_lead_data
    @graph.get_object(@lead_id)
  end

  def map_fields(fields)
    mapped_attributes = { source: :meta }

    fields.each do |field|
      case field["name"]
      when "full_name" then mapped_attributes[:name] = field["values"].first
      when "email" then mapped_attributes[:email] = field["values"].first
      when "phone_number" then mapped_attributes[:phone] = field["values"].first
      when "street_address" then mapped_attributes[:address] = field["values"].first
      when "zip_code" then mapped_attributes[:zip_code] = field["values"].first
      when "state"
        state = State.find_by("abbreviation ILIKE ?", field["values"].first)
        mapped_attributes[:state_id] = state&.id
      end
    end
    mapped_attributes
  end
end
