class Settings::ZipcodesController < ApplicationController
  include Authorization
  before_action -> { require_admin!(message: "Acceso no autorizado") }
  before_action :set_zipcode, only: [:show, :edit, :update, :destroy]

  def index
    @zipcodes = Zipcode.includes(city: :state).ordered
    
    # Filtro por búsqueda de código postal
    if params[:query].present?
      @zipcodes = @zipcodes.where("code ILIKE ?", "%#{params[:query]}%")
    end

    # Filtro por ciudad
    if params[:city_id].present?
      @zipcodes = @zipcodes.where(city_id: params[:city_id])
    end

    # Filtro por estado
    if params[:state_id].present?
      @zipcodes = @zipcodes.joins(city: :state).where(cities: { state_id: params[:state_id] })
    end

    @cities = City.includes(:state).ordered
    @states = State.ordered
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
    @cities = City.includes(:state).ordered
    @states = State.ordered
  end
end