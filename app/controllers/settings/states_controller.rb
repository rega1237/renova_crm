class Settings::StatesController < ApplicationController
  before_action :set_state, only: [ :show, :edit, :update, :destroy ]

  def index
    @states = State.ordered
  end

  def show
  end

  def new
    @state = State.new
  end

  def create
    @state = State.new(state_params)

    if @state.save
      redirect_to settings_states_path, notice: "Estado creado exitosamente."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @state.update(state_params)
      redirect_to settings_state_path(@state), notice: "Estado actualizado exitosamente."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @state.clients.any?
      redirect_to settings_states_path, alert: "No se puede eliminar el estado porque tiene clientes asociados."
    else
      @state.destroy
      redirect_to settings_states_path, notice: "Estado eliminado exitosamente."
    end
  end

  private

  def set_state
    @state = State.find(params[:id])
  end

  def state_params
    params.require(:state).permit(:name, :abbreviation)
  end
end
