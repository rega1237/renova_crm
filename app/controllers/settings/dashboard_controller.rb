class Settings::DashboardController < ApplicationController
  before_action :require_admin

  def index
    @facebook_integration = FacebookIntegration.first
  end

  def import_clients
    unless params[:file].present?
      redirect_to settings_root_path, alert: "Debes seleccionar un archivo Excel (.xlsx o .xls)." and return
    end

    service = ClientsImportService.new(params[:file], current_user: Current.user)
    result = service.call(update_existing: false)

    flash_message = "Importación completada: #{result.imported_clients_count} nuevos clientes, #{result.notes_created_count} notas. " \
                    "#{result.warnings.count} advertencias, #{result.errors.count} errores."
    if result.errors.any?
      flash_message += " Errores: #{result.errors.take(5).join(' | ')}"
    end
    redirect_to settings_root_path, notice: flash_message
  rescue => e
    redirect_to settings_root_path, alert: "Error al procesar el archivo: #{e.message}"
  end

  private

  def require_admin
    unless Current.user&.admin?
      redirect_to root_path, alert: "No autorizado."
    end
  end
end
