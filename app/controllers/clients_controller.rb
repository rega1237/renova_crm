class ClientsController < ApplicationController
  before_action :set_sellers, only: %i[ new edit create update ]
  before_action :set_client, only: %i[ show edit update destroy ]

  def index
    # Empezamos con todos los clientes
    @clients = Client.all

    # Filtramos por el texto de búsqueda (query) si está presente
    if params[:query].present?
      # Usamos ILIKE para una búsqueda insensible a mayúsculas/minúsculas (funciona en PostgreSQL)
      @clients = @clients.where("name ILIKE ?", "%#{params[:query]}%")
    end

    # Filtramos por status si está presente
    if params[:status].present?
      @clients = @clients.where(status: params[:status])
    end

    # Filtramos por source si está presente
    if params[:source].present?
      @clients = @clients.where(source: params[:source])
    end
  end

  def show
    @client = Client.find(params[:id])
  end

  # GET /clients/new
  def new
    @client = Client.new
  end

  # GET /clients/1/edit
  def edit
  end

  # POST /clients
  def create
    @client = Client.new(client_params)
    print "============================"
    print @client
    if @client.save
      redirect_to clients_path, notice: "Cliente creado exitosamente."
    else
      render :new, status: :unprocessable_content
    end
  end

  # PATCH/PUT /clients/1
  def update
    if @client.update(client_params)
      redirect_to clients_path, notice: "Cliente actualizado exitosamente."
    else
      render :edit, status: :unprocessable_content
    end
  end

  # DELETE /clients/1
  def destroy
    @client.destroy
    redirect_to clients_url, notice: "Cliente eliminado exitosamente."
  end

  private
    def set_client
      @client = Client.find(params[:id])
    end

    # Carga la lista de vendedores para el dropdown en el formulario
    def set_sellers
      @sellers = Seller.order(:name)
    end

    def client_params
      params.require(:client).permit(:name, :phone, :email, :address, :zip_code, :state, :status, :source, :seller_id)
    end
end
