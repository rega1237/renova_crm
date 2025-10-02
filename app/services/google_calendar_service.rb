
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
      start: Google::Apis::CalendarV3::EventDateTime.new(
        date_time: appointment.start_time.iso8601,
        time_zone: "America/New_York" # O la zona horaria que corresponda
      ),
      end: Google::Apis::CalendarV3::EventDateTime.new(
        date_time: appointment.end_time.iso8601,
        time_zone: "America/New_York" # O la zona horaria que corresponda
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

  private

  def calendar_service
    @calendar_service ||= begin
      service = Google::Apis::CalendarV3::CalendarService.new
      service.authorization = credentials
      service
    end
  end

  def credentials
    client_id = Google::Auth::ClientId.new(
      Rails.application.credentials.dig(:google_oauth2, :client_id),
      Rails.application.credentials.dig(:google_oauth2, :client_secret)
    )

    authorizer = Google::Auth::UserAuthorizer.new(client_id, Google::Apis::CalendarV3::AUTH_CALENDAR, nil)

    creds = authorizer.get_credentials_from_relation(@integration.attributes)
    creds.refresh! if creds.expired?

    # Guardar los tokens actualizados si se refrescaron
    if creds.refresh_token != @integration.refresh_token || creds.access_token != @integration.access_token
      @integration.update(
        access_token: creds.access_token,
        refresh_token: creds.refresh_token,
        expires_at: Time.at(creds.expires_in + Time.now.to_i)
      )
    end

    creds
  end

  def build_attendees(appointment)
    attendees = []
    # Añadir al cliente si tiene email
    if appointment.client.email.present?
      attendees << Google::Apis::CalendarV3::EventAttendee.new(email: appointment.client.email)
    end
    # Añadir al vendedor asignado si existe y tiene email
    if appointment.seller&.email.present?
      attendees << Google::Apis::CalendarV3::EventAttendee.new(email: appointment.seller.email)
    end
    attendees
  end
end
