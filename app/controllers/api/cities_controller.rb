module Api
  class CitiesController < ApplicationController
    def index
      state_id = params[:state_id]

      cache_key = [
        "api:cities_with_clients",
        (state_id.present? ? "state=#{state_id}" : "all")
      ].join(":")

      cities = Rails.cache.fetch(cache_key, expires_in: 10.minutes) do
        scope = City.joins("INNER JOIN clients ON clients.city_id = cities.id")
        scope = scope.where(state_id: state_id) if state_id.present?
        scope.distinct.order(:name).select(:id, :name, :state_id)
      end

      render json: cities
    end
  end
end
