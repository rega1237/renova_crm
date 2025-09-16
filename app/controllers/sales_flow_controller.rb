# app/controllers/sales_flow_controller.rb
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
  end

  def load_clients_by_status
    # Definir todos los status en el orden correcto
    statuses = %w[lead no_contesto seguimiento cita_agendada reprogramar vendido mal_credito no_cerro]

    clients_by_status = {}

    statuses.each do |status|
      clients = Client.includes(:state, :seller, :notes)
                     .where(status: status)

      # Aplicar filtros
      clients = clients.where("name ILIKE ?", "%#{@query}%") if @query.present?
      clients = clients.where(source: @source_filter) if @source_filter.present?
      clients = clients.where(state_id: @state_filter) if @state_filter.present?

      clients_by_status[status] = clients.order(:name).limit(50) # Limitar para performance
    end

    clients_by_status
  end
end
