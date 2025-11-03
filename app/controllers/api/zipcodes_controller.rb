module Api
  class ZipcodesController < ApplicationController
    # Devuelve lista de códigos postales válidos (5 dígitos) basados en filtros jerárquicos
    def index
      state_id = params[:state_id]
      city_id = params[:city_id]
      query = params[:q].to_s.strip

      base = Client.where.not(zip_code: [nil, ""]) 
      base = base.where(state_id: state_id) if state_id.present?
      base = base.where(city_id: city_id) if city_id.present?
      base = base.where("zip_code ~ ?", '^\\d{5}$')
      base = base.where("zip_code LIKE ?", "%#{query}%") if query.present?

      zipcodes = base.distinct.order(:zip_code).pluck(:zip_code)
      render json: { zipcodes: zipcodes }
    end
  end
end