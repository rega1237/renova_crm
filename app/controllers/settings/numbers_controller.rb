class Settings::NumbersController < ApplicationController
  before_action :set_number, only: [:show, :edit, :update, :destroy]

  def index
    @numbers = Number.includes(:user).order(created_at: :desc)
  end

  def show
  end

  def new
    @number = Number.new(status: :active)
    load_form_collections
  end

  def create
    @number = Number.new(number_params)
    if @number.save
      redirect_to settings_numbers_path, notice: "Número creado exitosamente."
    else
      load_form_collections
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    load_form_collections
  end

  def update
    if @number.update(number_params)
      redirect_to settings_number_path(@number), notice: "Número actualizado exitosamente."
    else
      load_form_collections
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @number.destroy
    redirect_to settings_numbers_path, notice: "Número eliminado exitosamente."
  end

  private

  def set_number
    @number = Number.find(params[:id])
  end

  def number_params
    params.require(:number).permit(:phone_number, :state, :status, :user_id)
  end

  def load_form_collections
    @users = User.order(:name)
    @states = State.order(:name)
  end
end