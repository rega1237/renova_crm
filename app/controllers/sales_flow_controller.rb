class SalesFlowController < ApplicationController
  before_action :set_filters, only: [:index, :load_more, :counts]

  def index
    @clients_by_status = load_clients_by_status
    @total_counts_by_status = total_counts_by_status
    @states = State.order(:name)

    respond_to do |format|
      format.html
      format.turbo_stream
    end
  end

  # Carga incremental para una columna específica (infinite scroll)
  def load_more
    status = params[:status]
    offset = params[:offset].to_i
    return head :bad_request unless status.present?

    clients = base_scope_for_status(status)
    clients = apply_filters(clients)
    clients = order_scope_for_status(clients, status)
    clients = clients.offset(offset).limit(50)

    render partial: "sales_flow/client_card", collection: clients, as: :client
  end

  # Endpoint liviano para refrescar totales (usado por ActionCable)
  def counts
    render json: total_counts_by_status
  end

  private

  def set_filters
    @query = params[:query]
    @status_filter = params[:status]
    @source_filter = params[:source]
    @state_filter = params[:state_id]
    @date_from = params[:date_from]
    @date_to = params[:date_to]
  end

  def load_clients_by_status
    statuses = %w[lead no_contesto no_aplica_no_interesado seguimiento cita_agendada reprogramar vendido mal_credito no_cerro]

    clients_by_status = {}

    statuses.each do |status|
      clients = base_scope_for_status(status)
      clients = apply_filters(clients)
      clients = order_scope_for_status(clients, status)

      # Mostrar inicialmente 50 por columna (performance)
      clients_by_status[status] = clients.limit(50)
    end

    clients_by_status
  end

  # Alcance base por status con includes necesarios
  def base_scope_for_status(status)
    Client.includes(:state, :prospecting_seller, :assigned_seller, :notes, :updated_by)
          .where(status: status)
  end

  # Aplicar filtros comunes
  def apply_filters(scope)
    scope = scope.where("name ILIKE ?", "%#{@query}%") if @query.present?
    scope = scope.where(source: @source_filter) if @source_filter.present?
    scope = scope.where(state_id: @state_filter) if @state_filter.present?

    # Filtro por rango de fechas
    if @date_from.present? || @date_to.present?
      scope = scope.by_date_range(@date_from, @date_to)
    end

    scope
  end

  # Totales por status (aplicando los mismos filtros) para los contadores "cargados/total"
  def total_counts_by_status
    statuses = %w[lead no_contesto no_aplica_no_interesado seguimiento cita_agendada reprogramar vendido mal_credito no_cerro]
    totals = {}

    statuses.each do |status|
      scope = base_count_scope_for_status(status)
      scope = apply_filters(scope)
      totals[status] = scope.count
    end

    totals
  end

  # Alcance base para COUNT (sin includes para optimizar el conteo)
  def base_count_scope_for_status(status)
    Client.where(status: status)
  end

  # Ordenar por la fecha relevante
  def order_scope_for_status(scope, status)
    if status == "lead"
      scope.order(created_at: :desc)
    else
      scope.order(Arel.sql("COALESCE(updated_status_at, created_at) DESC"))
    end
  end
end
