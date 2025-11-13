# frozen_string_literal: true

# País por defecto para normalización de teléfonos (PhonyRails)
# Prioriza Rails credentials, luego ENV, y como fallback usa US.
DEFAULT_PHONE_COUNTRY = (
  Rails.application.credentials.dig(:phone, :default_country) || ENV["DEFAULT_PHONE_COUNTRY"] || "US"
)
