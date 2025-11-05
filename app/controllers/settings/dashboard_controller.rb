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

    # Guardar archivo temporalmente para el job
    tmp_dir = Rails.root.join("tmp", "imports")
    FileUtils.mkdir_p(tmp_dir)
    pid = SecureRandom.uuid
    ext = File.extname(params[:file].original_filename.to_s)
    tmp_path = tmp_dir.join("clients_#{pid}#{ext}")
    File.open(tmp_path, "wb") { |f| f.write(params[:file].read) }

    update_existing = params[:update_existing] == "1"
    ClientsImportJob.perform_later(tmp_path.to_s, pid, Current.user.id, update_existing)

    redirect_to settings_progress_path(pid: pid, title: "Importación de Clientes")
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
  public

  # Página genérica de progreso que suscribe al canal usando pid
  def progress
    @pid = params[:pid].to_s
    @title = params[:title].to_s
    if @pid.blank?
      redirect_to settings_root_path, alert: "ID de progreso inválido" and return
    end
    render :progress
  end

  # === DEDUPE BUTTONS ===
  def dedupe_clients_dry_run
    ClientsDedupeJob.perform_later(Current.user.id, dry_run: true, keep_strategy: params[:keep_strategy].presence || "oldest")
    redirect_to settings_root_path, notice: "Se inició la simulación de deduplicación (Dry Run). Revisa los logs para ver el resultado."
  rescue => e
    redirect_to settings_root_path, alert: "Error al iniciar Dry Run de deduplicación: #{e.message}"
  end

  def dedupe_clients
    ClientsDedupeJob.perform_later(Current.user.id, dry_run: false, keep_strategy: params[:keep_strategy].presence || "oldest")
    redirect_to settings_root_path, notice: "Se inició la deduplicación real. Revisa los logs para ver el progreso y el resultado."
  rescue => e
    redirect_to settings_root_path, alert: "Error al iniciar deduplicación: #{e.message}"
  end

end
