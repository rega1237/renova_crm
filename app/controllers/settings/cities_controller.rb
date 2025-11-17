class Settings::CitiesController < ApplicationController
  before_action :set_city, only: [ :show, :edit, :update, :destroy ]

  def index
    scope = City.includes(:state).ordered
    @per_page = params[:per_page].presence&.to_i || 50
    @page = params[:page].presence&.to_i || 1
    @cities = scope.limit(@per_page).offset((@page - 1) * @per_page)
    @has_more = scope.count > (@page * @per_page)

    # Para peticiones de scroll infinito: devolver solo filas
    if params[:only_rows].present?
      render partial: "settings/cities/row", collection: @cities, as: :city, layout: false
      nil
    end
  end

  def show
  end

  def new
    @city = City.new
  end

  def create
    @city = City.new(city_params)
    if @city.save
      redirect_to settings_cities_path, notice: "Ciudad creada exitosamente."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @city.update(city_params)
      redirect_to settings_city_path(@city), notice: "Ciudad actualizada exitosamente."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @city.destroy
    redirect_to settings_cities_path, notice: "Ciudad eliminada exitosamente."
  end

  private

  def set_city
    @city = City.find(params[:id])
  end

  def city_params
    params.require(:city).permit(:name, :abbreviation, :state_id)
  end
end
