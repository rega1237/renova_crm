class UpdateGoogleEventJob < ApplicationJob
  queue_as :default

  def perform(appointment)
    google_integration = GoogleIntegration.first

    unless google_integration
      Rails.logger.error "No se encontró una integración de Google. No se puede actualizar el evento."
      return
    end

    service = GoogleCalendarService.new(google_integration)

    begin
      service.update_event(appointment)
      Rails.logger.info "Evento de Google actualizado exitosamente para la cita #{appointment.id}"
    rescue => e
      Rails.logger.error "Error al actualizar el evento de Google para la cita #{appointment.id}: #{e.message}"
    end
  end
end
