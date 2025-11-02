class Settings::ZipcodesController < ApplicationController
  include Authorization
  before_action -> { require_admin!(message: "Acceso no autorizado") }
  before_action :set_zipcode, only: [:show, :edit, :update, :destroy]

  def index
    scope = Zipcode.includes(city: :state).ordered
    
    # Filtro por búsqueda de código postal
    if params[:query].present?
      scope = scope.where("code ILIKE ?", "%#{params[:query]}%")
    end

    # Filtro por ciudad
    if params[:city_id].present?
      scope = scope.where(city_id: params[:city_id])
    end

    # Filtro por estado
    if params[:state_id].present?
      scope = scope.joins(city: :state).where(cities: { state_id: params[:state_id] })
    end

    @per_page = params[:per_page].presence&.to_i || 50
    @page = params[:page].presence&.to_i || 1
    @zipcodes = scope.limit(@per_page).offset((@page - 1) * @per_page)
    @has_more = scope.count > (@page * @per_page)

    # Ciudades para el filtro dependiente: si hay estado seleccionado, limitar ciudades a ese estado
    @cities = if params[:state_id].present?
                City.where(state_id: params[:state_id]).ordered
              else
                City.includes(:state).ordered
              end
    @states = State.ordered

    # Para peticiones de scroll infinito: devolver solo filas
    if params[:only_rows].present?
      render partial: "settings/zipcodes/row", collection: @zipcodes, as: :zipcode, layout: false
      return
    end
  end

  def show
  end

  def new
    @zipcode = Zipcode.new
    load_form_collections
  end

  def create
    @zipcode = Zipcode.new(zipcode_params)
    if @zipcode.save
      redirect_to settings_zipcodes_path, notice: "Código postal creado exitosamente."
    else
      load_form_collections
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    load_form_collections
  end

  def update
    if @zipcode.update(zipcode_params)
      redirect_to settings_zipcode_path(@zipcode), notice: "Código postal actualizado exitosamente."
    else
      load_form_collections
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @zipcode.destroy
    redirect_to settings_zipcodes_path, notice: "Código postal eliminado exitosamente."
  end

  private

  def set_zipcode
    @zipcode = Zipcode.find(params[:id])
  end

  def zipcode_params
    params.require(:zipcode).permit(:code, :city_id)
  end

  def load_form_collections
    @states = State.ordered
    # Para formularios nuevo/editar: si hay estado seleccionado (por params o por la ciudad del zipcode), limitar ciudades
    @selected_state_id = params[:state_id].presence || @zipcode&.city&.state_id
    @cities = if @selected_state_id.present?
                City.where(state_id: @selected_state_id).ordered
              else
                City.includes(:state).ordered
              end
  end
end