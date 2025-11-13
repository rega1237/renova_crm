# frozen_string_literal: true

# Configuración de credenciales para Twilio.
# Preferimos Rails credentials y, como fallback, variables de entorno.
#
# Requisitos en producción:
# - TWILIO_ACCOUNT_SID
# - TWILIO_AUTH_TOKEN
# Opcional:
# - TWILIO_DEFAULT_CALL_URL (Webhook para instrucciones de TwiML)
# - TWILIO_API_KEY_SID / TWILIO_API_KEY_SECRET (para emitir tokens del Voice SDK en navegador)
# - TWILIO_TWIML_APP_SID (aplicación TwiML configurada en Twilio; su Voice URL debe apuntar a /twilio/voice/connect)

TWILIO_ACCOUNT_SID = (
  Rails.application.credentials.dig(:twilio, :account_sid) || ENV["TWILIO_ACCOUNT_SID"]
)

TWILIO_AUTH_TOKEN = (
  Rails.application.credentials.dig(:twilio, :auth_token) || ENV["TWILIO_AUTH_TOKEN"]
)

# En producción, asegúrate de que las credenciales existan al ARRANCAR LA APP.
# Nota importante: durante el build de Docker hacemos `assets:precompile` con
# SECRET_KEY_BASE_DUMMY=1 y sin master key/secrets. En ese contexto no debemos
# exigir las credenciales de Twilio (no son necesarias para compilar assets).
# Por eso, el chequeo se salta si SECRET_KEY_BASE_DUMMY está presente.
if Rails.env.production? && ENV["SECRET_KEY_BASE_DUMMY"].blank?
  if TWILIO_ACCOUNT_SID.blank? || TWILIO_AUTH_TOKEN.blank?
    Rails.logger.error("Faltan credenciales de Twilio: configura Rails credentials o variables de entorno.")
    raise "Missing Twilio credentials (TWILIO_ACCOUNT_SID/TWILIO_AUTH_TOKEN)"
  end
end

# Advertencia en logs si faltan claves para WebRTC
if Rails.env.production? && ENV["SECRET_KEY_BASE_DUMMY"].blank?
  api_key_sid = Rails.application.credentials.dig(:twilio, :api_key_sid) || ENV["TWILIO_API_KEY_SID"]
  api_key_secret = Rails.application.credentials.dig(:twilio, :api_key_secret) || ENV["TWILIO_API_KEY_SECRET"]
  twiml_app_sid = Rails.application.credentials.dig(:twilio, :twiml_app_sid) || ENV["TWILIO_TWIML_APP_SID"]
  if api_key_sid.blank? || api_key_secret.blank? || twiml_app_sid.blank?
    Rails.logger.warn("Twilio WebRTC no está completamente configurado: faltan API KEY SID/SECRET o TWIML APP SID")
  end
end

# Nota: CallService permite inyectar el cliente Twilio en tests.
# En runtime, usa Twilio::REST::Client.new(TWILIO_ACCOUNT_SID, TWILIO_AUTH_TOKEN).
