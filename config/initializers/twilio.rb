# frozen_string_literal: true

# Twilio initializer
#
# Loads Twilio credentials from Rails credentials or environment variables.
# We do NOT fail-fast here to avoid breaking Docker asset precompilation.
# Service objects (e.g., CallService) should validate credentials at runtime
# when Twilio functionality is actually invoked.

require "active_support/core_ext/object/blank"

TWILIO_ACCOUNT_SID = Rails.application.credentials.dig(:twilio, :account_sid) || ENV["TWILIO_ACCOUNT_SID"] unless defined?(TWILIO_ACCOUNT_SID)
TWILIO_AUTH_TOKEN  = Rails.application.credentials.dig(:twilio, :auth_token)  || ENV["TWILIO_AUTH_TOKEN"]  unless defined?(TWILIO_AUTH_TOKEN)

# Note: We do not instantiate Twilio::REST::Client here to keep boot times
# and tests uncomplicated. The service objects (e.g., CallService) should
# instantiate the client as needed, using these credentials.