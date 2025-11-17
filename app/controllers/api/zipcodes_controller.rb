module Api
  class ZipcodesController < ApplicationController
    # Devuelve lista de códigos postales válidos (5 dígitos) basados en filtros jerárquicos
    def index
      state_id = params[:state_id]
      city_id = params[:city_id]
      query = params[:q].to_s.strip
      # Si use_model=true o source=model, usamos el modelo Zipcode
      use_model = ActiveModel::Type::Boolean.new.cast(params[:use_model]) || params[:source] == "model" || ActiveModel::Type::Boolean.new.cast(params[:all])

      cache_key = [
        (use_model ? "api:zipcodes_model" : "api:zipcodes_with_clients"),
        (state_id.present? ? "state=#{state_id}" : "all"),
        (city_id.present? ? "city=#{city_id}" : "none"),
        (query.present? ? "q=#{query}" : "q=")
      ].join(":")

      result = Rails.cache.fetch(cache_key, expires_in: 5.minutes) do
        if use_model
          base = Zipcode.includes(city: :state)
          base = base.joins(:city)
          base = base.where(cities: { state_id: state_id }) if state_id.present?
          base = base.where(city_id: city_id) if city_id.present?
          base = base.where("zipcodes.code ILIKE ?", "%#{query}%") if query.present?
          base.order(:code).map { |z| { code: z.code, city_id: z.city_id, city_name: z.city.name, state_abbr: z.city.state&.abbreviation } }
        else
          base = Client.where.not(zip_code: [ nil, "" ])
          base = base.where(state_id: state_id) if state_id.present?
          base = base.where(city_id: city_id) if city_id.present?
          base = base.where("zip_code ~ ?", '^\\d{5}$')
          base = base.where("zip_code LIKE ?", "%#{query}%") if query.present?
          base.distinct.order(:zip_code).pluck(:zip_code)
        end
      end

      render json: { zipcodes: result }
    end
  end
end
