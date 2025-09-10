class Admin::UsersController < ApplicationController
  before_action :require_admin
  before_action :set_user, only: [ :show, :edit, :update, :destroy ]
  def index
    @users = User.all
  end

  def show
  end

  def new
    @user = User.new
  end

  def create
    @user = User.new(user_params)
    if @user.save
      redirect_to admin_users_path, notice: "Usuario creado exitosamente."
    else
      render :new
    end
  end

  def edit
    @user = User.find(params[:id])
  end

  def update
    @user = User.find(params[:id])
    if @user.update(user_params)
      redirect_to admin_users_path, notice: "Usuario actualizado exitosamente."
    else
      render :edit
    end
  end

  def destroy
    @user = User.find(params[:id])
    @user.destroy
    redirect_to admin_users_path, notice: "Usuario eliminado exitosamente."
  end

  private

  def user_params
    params.require(:user).permit(:nombre, :email, :rol, :password, :password_confirmation)
  end

  def set_user
    @user = User.find(params[:id])
  end

  def require_admin
    # Asegúrate de que el usuario actual es un admin
    unless Current.user&.admin?
      redirect_to root_path, alert: "No tienes permiso para acceder a esta p\u00E1gina."
    end
  end
end
