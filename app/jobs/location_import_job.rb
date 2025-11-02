# frozen_string_literal: true

class LocationImportJob < ApplicationJob
  queue_as :default

  def perform(file_path, pid)
    broadcaster = ->(payload) { ActionCable.server.broadcast("progress:#{pid}", payload) }

    broadcaster.call(event: "start", message: "Leyendo archivo de ubicaciones...")

    service = LocationImportService.new(file_path)
    result = service.call_with_progress(on_progress: broadcaster)

    summary = {
      "Filas procesadas" => result.rows_processed,
      "Filas fallidas" => result.rows_failed,
      "Estados creados" => result.states_created,
      "Estados actualizados" => result.states_updated,
      "Ciudades creadas" => result.cities_created,
      "Zipcodes creados" => result.zipcodes_created,
      "Zipcodes existentes" => result.zipcodes_existing
    }

    broadcaster.call(event: "complete", message: "Importación de ubicaciones completada", summary: summary)
  ensure
    # Cleanup temp file
    begin
      File.delete(file_path) if file_path.present? && File.exist?(file_path)
    rescue StandardError
      # ignore
    end
  end
end