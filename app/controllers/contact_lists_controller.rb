class ContactListsController < ApplicationController
  include Authorization
  before_action -> { require_admin!(message: "Acceso no autorizado") }
  before_action :set_contact_list, only: [:show, :edit, :update, :destroy]

  def index
    @states_for_filter = State.ordered
    @query = params[:query]
    @state_id = params[:state_id]

    @contact_lists = ContactList
      .search(@query)
      .by_state(@state_id)
      .includes(:state)
      .order(:name)
  end

  def show
  end

  def new
    @contact_list = ContactList.new
  end

  def edit
  end

  def create
    @contact_list = ContactList.new(contact_list_params)
    if @contact_list.save
      redirect_to contact_list_path(@contact_list), notice: "Contacto creado exitosamente."
    else
      flash.now[:alert] = "No se pudo crear el contacto. Revisa los errores."
      render :new
    end
  end

  def update
    if @contact_list.update(contact_list_params)
      redirect_to contact_list_path(@contact_list), notice: "Contacto actualizado exitosamente."
    else
      flash.now[:alert] = "No se pudo actualizar el contacto. Revisa los errores."
      render :edit
    end
  end

  def destroy
    @contact_list.destroy
    redirect_to contact_lists_path, notice: "Contacto eliminado exitosamente."
  end

  private

  def set_contact_list
    @contact_list = ContactList.find(params[:id])
  end

  def contact_list_params
    params.require(:contact_list).permit(:name, :phone, :state_id)
  end
end