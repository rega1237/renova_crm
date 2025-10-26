class Settings::DashboardController < ApplicationController
  include Authorization
  before_action -> { require_admin!(message: "Acceso no autorizado") }

  def index
    @facebook_integration = FacebookIntegration.first
    @states = State.order(:name)
    @sellers = Seller.order(:name)
  end

  def import_clients
    unless params[:file].present?
      redirect_to settings_root_path, alert: "Debes seleccionar un archivo Excel (.xlsx o .xls)." and return
    end

    service = ClientsImportService.new(params[:file], current_user: Current.user)
    update_existing = params[:update_existing] == "1"
    result = service.call(update_existing: update_existing)

    flash_message = "Importación completada: #{result.imported_clients_count} nuevos clientes, " \
                    "#{result.updated_clients_count} actualizados, #{result.notes_created_count} notas. " \
                    "#{result.warnings.count} advertencias, #{result.errors.count} errores."
    if result.errors.any?
      flash_message += " Errores: #{result.errors.take(5).join(' | ')}"
    end
    redirect_to settings_root_path, notice: flash_message
  rescue => e
    redirect_to settings_root_path, alert: "Error al procesar el archivo: #{e.message}"
  end

  def export_clients
    clients = Client.includes(:state, :prospecting_seller, :assigned_seller)

    # Filtros opcionales similares al índice de clientes
    if params[:query].present?
      clients = clients.where("name ILIKE ?", "%#{params[:query]}%")
    end
    if params[:status].present?
      clients = clients.where(status: params[:status])
    end
    if params[:source].present?
      clients = clients.where(source: params[:source])
    end
    if params[:state_id].present?
      clients = clients.where(state_id: params[:state_id])
    end
    if params[:seller_id].present?
      clients = clients.where("prospecting_seller_id = ? OR assigned_seller_id = ?", params[:seller_id], params[:seller_id])
    end
    if params[:date_from].present? || params[:date_to].present?
      clients = clients.by_date_range(params[:date_from], params[:date_to])
    end

    exporter = ClientsExportService.new
    xlsx_data = exporter.call(clients)
    filename = "clientes_#{Time.current.strftime('%Y%m%d_%H%M')}.xlsx"
    send_data xlsx_data,
              filename: filename,
              type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
  rescue => e
    redirect_to settings_root_path, alert: "Error al exportar clientes: #{e.message}"
  end

  private

end
