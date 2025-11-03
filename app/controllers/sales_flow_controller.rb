class SalesFlowController < ApplicationController
  before_action :set_filters, only: [ :index, :load_more, :counts ]

  def index
    @clients_by_status = load_clients_by_status
    @total_counts_by_status = total_counts_by_status
    @states = State.order(:name)
    build_filter_collections

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
    @city_filter = params[:city_id]
    @zip_filter = params[:zip_code]
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
    Client.includes(:state, :city, :prospecting_seller, :assigned_seller, :notes, :updated_by)
          .where(status: status)
  end

  # Aplicar filtros comunes
  def apply_filters(scope)
    scope = scope.where("name ILIKE ?", "%#{@query}%") if @query.present?
    scope = scope.where(source: @source_filter) if @source_filter.present?
    scope = scope.where(state_id: @state_filter) if @state_filter.present?

    # Filtro por ciudad (incluye opción especial 'Sin ciudad')
    if @city_filter.present?
      if @city_filter == "none"
        scope = scope.where(city_id: nil)
      else
        scope = scope.where(city_id: @city_filter)
      end
    end

    # Filtro por rango de fechas
    if @date_from.present? || @date_to.present?
      scope = scope.by_date_range(@date_from, @date_to)
    end

    # Filtro por código postal (solo 5 dígitos)
    if @zip_filter.present?
      five = normalize_zip_param(@zip_filter)
      scope = scope.where(zip_code: five) if five.present?
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

  # Construye colecciones auxiliares para los dropdowns de filtros (ciudades y zipcodes)
  def build_filter_collections
    # Base para ciudades y ZIPs (incluye filtro por estado cuando aplique)
    base = Client.where(nil)
    base = base.where("name ILIKE ?", "%#{@query}%") if @query.present?
    base = base.where(source: @source_filter) if @source_filter.present?
    base = base.where(state_id: @state_filter) if @state_filter.present?
    if @date_from.present? || @date_to.present?
      base = base.by_date_range(@date_from, @date_to)
    end

    city_ids = base.where.not(city_id: nil).distinct.pluck(:city_id)
    @filter_cities = if @state_filter.present?
                       City.where(id: city_ids, state_id: @state_filter).ordered
                     else
                       City.where(id: city_ids).ordered
                     end

    zips_scope = base.where.not(zip_code: [ nil, "" ])
    if @city_filter.present? && @city_filter != "none"
      zips_scope = zips_scope.where(city_id: @city_filter)
    elsif @state_filter.present?
      zips_scope = zips_scope.where(state_id: @state_filter)
    end
    @zipcodes_for_filter = zips_scope.where("zip_code ~ ?", '^\\d{5}$').distinct.order(:zip_code).pluck(:zip_code)

    # Base separada para estados: solo los estados con clientes bajo los demás filtros (excluyendo state/city/zip)
    base_states = Client.where(nil)
    base_states = base_states.where("name ILIKE ?", "%#{@query}%") if @query.present?
    base_states = base_states.where(source: @source_filter) if @source_filter.present?
    if @date_from.present? || @date_to.present?
      base_states = base_states.by_date_range(@date_from, @date_to)
    end
    state_ids = base_states.where.not(state_id: nil).distinct.pluck(:state_id)
    @states_for_filter = State.where(id: state_ids).order(:name)
  end

  

  # Normaliza un valor de filtro de ZIP: devuelve los 5 dígitos base si existen
  def normalize_zip_param(value)
    v = value.to_s.strip
    return nil if v.blank?
    if v =~ /^\d{5}$/
      v
    else
      nil
    end
  end
end
