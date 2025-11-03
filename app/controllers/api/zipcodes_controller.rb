module Api
  class ZipcodesController < ApplicationController
    # Devuelve lista de códigos postales válidos (5 dígitos) basados en filtros jerárquicos
    def index
      state_id = params[:state_id]
      city_id = params[:city_id]
      query = params[:q].to_s.strip

      cache_key = [
        "api:zipcodes_with_clients",
        (state_id.present? ? "state=#{state_id}" : "all"),
        (city_id.present? ? "city=#{city_id}" : "none"),
        (query.present? ? "q=#{query}" : "q=")
      ].join(":")

      zipcodes = Rails.cache.fetch(cache_key, expires_in: 5.minutes) do
        base = Client.where.not(zip_code: [nil, ""]) 
        base = base.where(state_id: state_id) if state_id.present?
        base = base.where(city_id: city_id) if city_id.present?
        base = base.where("zip_code ~ ?", '^\\d{5}$')
        base = base.where("zip_code LIKE ?", "%#{query}%") if query.present?

        base.distinct.order(:zip_code).pluck(:zip_code)
      end

      render json: { zipcodes: zipcodes }
    end
  end
end