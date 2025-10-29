module Api
  class CitiesController < ApplicationController
    def index
      cities = if params[:state_id].present?
                 City.where(state_id: params[:state_id]).ordered
      else
                 City.ordered
      end

      render json: cities.select(:id, :name, :state_id)
    end
  end
end
