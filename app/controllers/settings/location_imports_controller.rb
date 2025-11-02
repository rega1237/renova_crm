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

    service = LocationImportService.new(file)
    result = service.call

    @result = result
    render :result
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