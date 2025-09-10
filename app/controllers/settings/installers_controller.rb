class Settings::InstallersController < ApplicationController
    before_action :set_installer, only: %i[ show edit update destroy ]

  def index
    @installers = Installer.all
  end

  def show
  end

  def new
    @installer = Installer.new
  end

  def edit
  end

  def create
    @installer = Installer.new(installer_params)
    if @installer.save
      redirect_to settings_installers_path, notice: "Instalador creado exitosamente."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @installer.update(installer_params)
      redirect_to settings_installers_path, notice: "Instalador actualizado exitosamente."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @installer.destroy
    redirect_to settings_installers_path, notice: "Instalador eliminado exitosamente."
  end

  private

  def set_installer
    @installer = Installer.find(params[:id])
  end

  def installer_params
    params.require(:installer).permit(:name, :phone, :email)
  end
end
