class Settings::SellersController < ApplicationController
  def index
    @sellers = Seller.all
  end

  def show
    @seller = Seller.find(params[:id])
  end

  def new
    @seller = Seller.new
  end

  def create
    @seller = Seller.new(seller_params)
    if @seller.save
      redirect_to settings_sellers_path, notice: "Vendedor creado con éxito"
    else
      render :new
    end
  end

  def edit
    @seller = Seller.find(params[:id])
  end

  def update
    @seller = Seller.find(params[:id])
    if @seller.update(seller_params)
      redirect_to settings_sellers_path, notice: "Vendedor actualizado con éxito"
    else
      render :edit
    end
  end

  def destroy
    @seller = Seller.find(params[:id])
    @seller.destroy
    redirect_to settings_sellers_path, notice: "Vendedor eliminado con éxito"
  end

  private

  def seller_params
    params.require(:seller).permit(:name, :email, :phone)
  end
end
