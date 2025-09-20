class SalesFlowController < ApplicationController
  before_action :set_filters, only: [ :index ]

  def index
    @clients_by_status = load_clients_by_status
    @states = State.order(:name)

    respond_to do |format|
      format.html
      format.turbo_stream
    end
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
    statuses = %w[lead no_contesto seguimiento cita_agendada reprogramar vendido mal_credito no_cerro]

    clients_by_status = {}

    statuses.each do |status|
      clients = Client.includes(:state, :seller, :notes, :updated_by)
                     .where(status: status)

      # Aplicar filtros
      clients = clients.where("name ILIKE ?", "%#{@query}%") if @query.present?
      clients = clients.where(source: @source_filter) if @source_filter.present?
      clients = clients.where(state_id: @state_filter) if @state_filter.present?

      # Aplicar filtro de fechas
      if @date_from.present? || @date_to.present?
        clients = clients.by_date_range(@date_from, @date_to)
      end

      # Ordenar por fecha relevante: leads por created_at, otros por updated_status_at
      # Más nuevos primero (DESC)
      if status == "lead"
        clients = clients.order(created_at: :desc)
      else
        # Para no-leads, ordenar por updated_status_at, pero como fallback usar created_at si es null
        clients = clients.order(
          Arel.sql("COALESCE(updated_status_at, created_at) DESC")
        )
      end

      clients_by_status[status] = clients.limit(50) # Limitar para performance
    end

    clients_by_status
  end
end
