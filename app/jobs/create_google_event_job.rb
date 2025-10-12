class CreateGoogleEventJob < ApplicationJob
  queue_as :default

  def perform(appointment)
    google_integration = GoogleIntegration.first

    unless google_integration
      Rails.logger.error "No se encontró una integración de Google para el usuario #{appointment.created_by.id}. No se puede crear el evento."
      return
    end

    service = GoogleCalendarService.new(google_integration)

    begin
      google_event_id = service.create_event(appointment)
      appointment.update!(google_event_id: google_event_id)
      Rails.logger.info "Evento de Google creado exitosamente con ID: #{google_event_id} para la cita #{appointment.id}"
    rescue => e
      Rails.logger.error "Error al crear el evento de Google para la cita #{appointment.id}: #{e.message}"
    end
  end
end
