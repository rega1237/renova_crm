# frozen_string_literal: true

class ClientsImportJob < ApplicationJob
  queue_as :default

  def perform(file_path, pid, current_user_id, update_existing)
    broadcaster = ->(payload) { ActionCable.server.broadcast("progress:#{pid}", payload) }

    broadcaster.call(event: "start", message: "Leyendo archivo de clientes...")

    user = User.find_by(id: current_user_id)
    service = ClientsImportService.new(file_path, current_user: user)
    result = service.call_with_progress(update_existing: update_existing, on_progress: broadcaster)

    summary = {
      "Filas totales" => result.total_rows,
      "Clientes importados" => result.imported_clients_count,
      "Clientes actualizados" => result.updated_clients_count,
      "Notas creadas" => result.notes_created_count,
      "Advertencias" => result.warnings.count,
      "Errores" => result.errors.count
    }

    broadcaster.call(event: "complete", message: "Importación de clientes completada", summary: summary)
  ensure
    begin
      File.delete(file_path) if file_path.present? && File.exist?(file_path)
    rescue StandardError
    end
  end
end
