module Api
  class CitiesController < ApplicationController
    def index
      state_id = params[:state_id]
      q = params[:q].to_s.strip
      # Cuando all=true devolvemos todas las ciudades del modelo City (no solo con clientes)
      return_all = ActiveModel::Type::Boolean.new.cast(params[:all])

      cache_key = [
        (return_all ? "api:cities_all" : "api:cities_with_clients"),
        (state_id.present? ? "state=#{state_id}" : "all"),
        (q.present? ? "q=#{q}" : "q=")
      ].join(":")

      cities = Rails.cache.fetch(cache_key, expires_in: 10.minutes) do
        scope = return_all ? City.all : City.joins("INNER JOIN clients ON clients.city_id = cities.id")
        scope = scope.where(state_id: state_id) if state_id.present?
        scope = scope.where("cities.name ILIKE ?", "%#{q}%") if q.present?
        scope.distinct.order(:name).select(:id, :name, :state_id)
      end

      render json: cities
    end
  end
end
