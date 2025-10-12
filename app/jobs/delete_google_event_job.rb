class DeleteGoogleEventJob < ApplicationJob
  queue_as :default

  def perform(appointment)
    google_integration = GoogleIntegration.first

    unless google_integration
      Rails.logger.error "No se encontró una integración de Google. No se puede eliminar el evento."
      return
    end

    service = GoogleCalendarService.new(google_integration)

    begin
      Rails.logger.debug "Attempting to delete Google Event ID: #{appointment.google_event_id} for Appointment ID: #{appointment.id}"
      service.delete_event(appointment)
      Rails.logger.info "Evento de Google eliminado exitosamente para la cita #{appointment.id}"
    rescue => e
      Rails.logger.error "Error al eliminar el evento de Google para la cita #{appointment.id}: #{e.message}"
    end
  end
end
