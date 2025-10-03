
require "google/apis/calendar_v3"
require "googleauth"
require "googleauth/stores/file_token_store"

class GoogleCalendarService
  CALENDAR_ID = "primary".freeze
  OOB_URI = "urn:ietf:wg:oauth:2.0:oob".freeze

  def initialize(google_integration)
    @integration = google_integration
  end

  def create_event(appointment)
    event = Google::Apis::CalendarV3::Event.new(
      summary: appointment.title,
      description: appointment.description,
      location: appointment.address,
      start: Google::Apis::CalendarV3::EventDateTime.new(
        date_time: appointment.start_time.strftime("%Y-%m-%dT%H:%M:%S"),
        time_zone: appointment.client.timezone
      ),
      end: Google::Apis::CalendarV3::EventDateTime.new(
        date_time: appointment.end_time.strftime("%Y-%m-%dT%H:%M:%S"),
        time_zone: appointment.client.timezone
      ),
      attendees: build_attendees(appointment),
      reminders: {
        use_default: false,
        overrides: [
          Google::Apis::CalendarV3::EventReminder.new(reminder_method: "email", minutes: 24 * 60),
          Google::Apis::CalendarV3::EventReminder.new(reminder_method: "popup", minutes: 30)
        ]
      }
    )

    result = calendar_service.insert_event(CALENDAR_ID, event, send_notifications: true)
    result.id
  end

  def update_event(appointment)
    return unless appointment.google_event_id

    event = Google::Apis::CalendarV3::Event.new(
      summary: appointment.title,
      description: appointment.description,
      location: appointment.address,
      start: Google::Apis::CalendarV3::EventDateTime.new(
        date_time: appointment.start_time.strftime("%Y-%m-%dT%H:%M:%S"),
        time_zone: appointment.client.timezone
      ),
      end: Google::Apis::CalendarV3::EventDateTime.new(
        date_time: appointment.end_time.strftime("%Y-%m-%dT%H:%M:%S"),
        time_zone: appointment.client.timezone
      ),
      attendees: build_attendees(appointment)
    )

    calendar_service.update_event(CALENDAR_ID, appointment.google_event_id, event, send_notifications: true)
  end

  def delete_event(appointment)
    return unless appointment.google_event_id
    calendar_service.delete_event(CALENDAR_ID, appointment.google_event_id)
  end

  private

  def calendar_service
    @calendar_service ||= begin
      service = Google::Apis::CalendarV3::CalendarService.new
      service.authorization = credentials
      service
    end
  end

  def credentials
    creds = Google::Auth::UserRefreshCredentials.new(
      client_id: Rails.application.credentials.dig(:google_oauth2, :client_id),
      client_secret: Rails.application.credentials.dig(:google_oauth2, :client_secret),
      scope: Google::Apis::CalendarV3::AUTH_CALENDAR,
      access_token: @integration.access_token,
      refresh_token: @integration.refresh_token,
      expires_at: @integration.expires_at
    )

    creds.fetch_access_token! if creds.expired?

    # Guardar los tokens actualizados si se refrescaron
    if creds.access_token != @integration.access_token
      @integration.update(
        access_token: creds.access_token,
        expires_at: creds.expires_at
      )
    end

    creds
  end

  def build_attendees(appointment)
    attendees = []
    # Añadir al vendedor asignado si existe y tiene email
    if appointment.seller&.email.present?
      attendees << Google::Apis::CalendarV3::EventAttendee.new(email: appointment.seller.email)
    end
    attendees
  end
end
