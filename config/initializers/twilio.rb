# frozen_string_literal: true

# Twilio initializer
#
# Loads Twilio credentials from Rails credentials or environment variables.
# In production, we fail fast when the web server boots if credentials are missing.
# This avoids raising during asset precompilation in Docker builds.

require "active_support/core_ext/object/blank"

TWILIO_ACCOUNT_SID = Rails.application.credentials.dig(:twilio, :account_sid) || ENV["TWILIO_ACCOUNT_SID"] unless defined?(TWILIO_ACCOUNT_SID)
TWILIO_AUTH_TOKEN  = Rails.application.credentials.dig(:twilio, :auth_token)  || ENV["TWILIO_AUTH_TOKEN"]  unless defined?(TWILIO_AUTH_TOKEN)

# Detect if we're running asset precompilation (skip fail-fast in this case)
skip_fail_fast = ENV["SECRET_KEY_BASE_DUMMY"].present? ||
                 (defined?(ARGV) && ARGV.any? { |a| a.to_s.start_with?("assets:") })
should_fail_fast = Rails.env.production? && !skip_fail_fast

if should_fail_fast
  if TWILIO_ACCOUNT_SID.blank? || TWILIO_AUTH_TOKEN.blank?
    Rails.logger.error("Missing Twilio credentials (TWILIO_ACCOUNT_SID/TWILIO_AUTH_TOKEN)")
    raise "Missing Twilio credentials (TWILIO_ACCOUNT_SID/TWILIO_AUTH_TOKEN)"
  end
end

# Note: We do not instantiate Twilio::REST::Client here to keep boot times
# and tests uncomplicated. The service objects (e.g., CallService) should
# instantiate the client as needed, using these credentials.

# Configuración de credenciales para Twilio.
# Preferimos Rails credentials y, como fallback, variables de entorno.

TWILIO_ACCOUNT_SID = (
  Rails.application.credentials.dig(:twilio, :account_sid) || ENV["TWILIO_ACCOUNT_SID"]
)

TWILIO_AUTH_TOKEN = (
  Rails.application.credentials.dig(:twilio, :auth_token) || ENV["TWILIO_AUTH_TOKEN"]
)

# En producción, asegúrate de que las credenciales existan al arrancar.
if Rails.env.production?
  if TWILIO_ACCOUNT_SID.blank? || TWILIO_AUTH_TOKEN.blank?
    Rails.logger.error("Faltan credenciales de Twilio: configura Rails credentials o variables de entorno.")
    raise "Missing Twilio credentials (TWILIO_ACCOUNT_SID/TWILIO_AUTH_TOKEN)"
  end
end

# Nota: CallService permite inyectar el cliente Twilio en tests.
# En runtime, usa Twilio::REST::Client.new(TWILIO_ACCOUNT_SID, TWILIO_AUTH_TOKEN).

# Twilio credentials are expected to be provided via environment variables.
# Ensure these are set in your deployment environment and local dev.
#
# Required:
# - TWILIO_ACCOUNT_SID
# - TWILIO_AUTH_TOKEN
# Optional:
# - TWILIO_DEFAULT_CALL_URL (Webhook for TwiML instructions)

TWILIO_ACCOUNT_SID = ENV["TWILIO_ACCOUNT_SID"]
TWILIO_AUTH_TOKEN  = ENV["TWILIO_AUTH_TOKEN"]

if Rails.env.production?
  if TWILIO_ACCOUNT_SID.blank? || TWILIO_AUTH_TOKEN.blank?
    Rails.logger.error("Twilio credentials missing: please set TWILIO_ACCOUNT_SID and TWILIO_AUTH_TOKEN")
    raise "Missing Twilio credentials"
  end
end