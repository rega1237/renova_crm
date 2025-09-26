class ClientsController < ApplicationController
  before_action :set_sellers, only: %i[ new edit create update ]
  before_action :set_client, only: %i[ show edit update destroy ]

  def index
    @clients = Client.includes(:state, :prospecting_seller, :assigned_seller, :updated_by).order(:name)

    # Filtro por búsqueda de nombre
    if params[:query].present?
      @clients = @clients.where("name ILIKE ?", "%#{params[:query]}%")
    end

    # Filtro por status del cliente
    if params[:status].present?
      @clients = @clients.where(status: params[:status])
    end

    # Filtro por fuente
    if params[:source].present?
      @clients = @clients.where(source: params[:source])
    end

    # Filtro por estado
    if params[:state_id].present?
      @clients = @clients.where(state_id: params[:state_id])
    end

    # Filtro por vendedor (busca en ambos campos)
    if params[:seller_id].present?
      @clients = @clients.where(
        "prospecting_seller_id = ? OR assigned_seller_id = ?",
        params[:seller_id],
        params[:seller_id]
      )
    end

    # Filtro por rango de fechas
    if params[:date_from].present? || params[:date_to].present?
      @clients = @clients.by_date_range(params[:date_from], params[:date_to])
    end

    @clients = @clients.order(created_at: :desc)
  end

  def show
    @client = Client.find(params[:id])
  end

  def new
    @client = Client.new
  end

  def edit
  end

  def create
    @client = Client.new(client_params)
    if @client.save
      redirect_to clients_path, notice: "Cliente creado exitosamente."
    else
      render :new, status: :unprocessable_content
    end
  end

  def update
    if @client.update(client_params)
      redirect_to clients_path, notice: "Cliente actualizado exitosamente."
    else
      render :edit, status: :unprocessable_content
    end
  end

  def update_status
    @client = Client.find(params[:id])
    old_status = @client.status
    new_status = params[:status]

    if @client.update(status: new_status)
      # Reload para obtener los datos actualizados incluyendo updated_by
      @client.reload

      # Broadcast del cambio via ActionCable con información adicional
      ActionCable.server.broadcast(
        "sales_flow_channel",
        {
          action: "client_moved",
          client_id: @client.id,
          client_name: @client.name,
          updated_by_name: @client.updated_by&.name || "Usuario desconocido",
          old_status: old_status,
          new_status: new_status,
          updated_at: @client.updated_status_at || @client.updated_at, # Incluir timestamp
          client_html: render_to_string(
            partial: "sales_flow/client_card",
            locals: { client: @client },
            formats: [ :html ]
          )
        }
      )

      render json: {
        status: "success",
        message: "Cliente actualizado correctamente",
        updated_at: @client.updated_status_at || @client.updated_at # Para el frontend
      }
    else
      render json: { status: "error", errors: @client.errors.full_messages }
    end
  end

  def update_assigned_seller
    @client = Client.find(params[:id])
    old_assigned_seller = @client.assigned_seller

    if @client.update(assigned_seller_id: params[:client][:assigned_seller_id])
      Rails.logger.info "Update exitoso"

      # Renderizamos el HTML de la tarjeta actualizada para el broadcast
      client_html = ApplicationController.render(
        partial: "sales_flow/client_card",
        locals: { client: @client }
      )

      ActionCable.server.broadcast(
        "sales_flow_channel",
        {
          action: "assigned_seller_updated",
          client_id: @client.id,
          new_seller_name: @client.assigned_seller&.name || "Sin asignar",
          client_html: client_html
        }
      )

      render turbo_stream: turbo_stream.replace(
        "assigned-seller-section",
        partial: "clients/assigned_seller_section",
        locals: { client: @client }
      )
    else
      render json: {
        status: "error",
        errors: @client.errors.full_messages,
        field_errors: @client.errors.messages
      }, status: :unprocessable_content
    end
  end

  def destroy
    @client.destroy
    redirect_to clients_url, notice: "Cliente eliminado exitosamente."
  end

  private
    def set_client
      @client = Client.find(params[:id])
    end

    def set_sellers
      @sellers = Seller.order(:name)
    end

    def client_params
      params.require(:client).permit(
        :name, :phone, :email, :address, :zip_code, :state_id,
        :status, :source, :prospecting_seller_id, :assigned_seller_id
      )
    end
end
