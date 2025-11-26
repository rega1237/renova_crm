class Settings::LocationImportsController < ApplicationController
  include Authorization
  before_action -> { require_admin!(message: "Acceso no autorizado") }

  def new
  end

  def create
    file = params[:file]
    unless valid_file?(file)
      flash.now[:alert] = "Archivo inválido. Debe ser un Excel (.xlsx, .xls)."
      render :new, status: :unprocessable_entity and return
    end

    # Guardar archivo temporalmente para el job
    tmp_dir = Rails.root.join("tmp", "imports")
    FileUtils.mkdir_p(tmp_dir)
    pid = SecureRandom.uuid
    # Usar extensión whitelisted en lugar de la original
    original_filename = file.original_filename.to_s.downcase
    ext = original_filename.end_with?(".xlsx") ? ".xlsx" : ".xls"
    tmp_path = tmp_dir.join("location_#{pid}#{ext}")
    File.open(tmp_path, "wb") { |f| f.write(file.read) }

    # Encolar job en segundo plano con progreso
    LocationImportJob.perform_later(tmp_path.to_s, pid)

    redirect_to settings_progress_path(pid: pid, title: "Importación de Ubicaciones")
  rescue => e
    Rails.logger.error("Location import failed: #{e.message}")
    flash.now[:alert] = "Error durante la importación: #{e.message}"
    render :new, status: :internal_server_error
  end

  private

  def valid_file?(file)
    return false if file.blank?
    filename = file.original_filename.to_s.downcase
    filename.end_with?(".xlsx") || filename.end_with?(".xls")
  end
end
