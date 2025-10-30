# frozen_string_literal: true

require "twilio-ruby"

module Twilio
  class VoiceController < ActionController::Base
    protect_from_forgery with: :null_session

    # Twilio hará una petición GET/POST a esta acción para obtener TwiML
    def connect
      # Log de diagnóstico: parámetros recibidos por el webhook
      Rails.logger.info("Twilio Voice connect params: #{params.to_unsafe_h.inspect}")
      # Este endpoint es llamado por Twilio cuando el navegador inicia una llamada
      # mediante el Voice SDK (outgoing_application_sid). Los parámetros incluidos
      # en Device.connect se reciben aquí (por ejemplo: To y From).

      to_number = params[:To] || params[:to]
      # Priorizar el caller_id numérico (E.164) enviado desde el cliente.
      # Twilio incluye From/Caller="client:<identity>", que NO es válido como callerId para <Dial> a PSTN.
      from_number = params[:caller_id] || params[:From] || params[:from]

      unless to_number.present? && from_number.present?
        Rails.logger.warn("Parámetros incompletos en /twilio/voice/connect: To=#{to_number.inspect}, From=#{from_number.inspect}")
        return render xml: empty_twiml_with_say("Parámetros incompletos"), status: :ok
      end

      # Validar callerId en formato E.164 (+E.164) requerido por Twilio
      unless from_number.present? && from_number.to_s.match?(/\A\+\d{8,15}\z/)
        Rails.logger.warn("callerId inválido en /twilio/voice/connect: caller_id=#{from_number.inspect}")
        return render xml: empty_twiml_with_say("callerId inválido para la llamada"), status: :ok
      end

      response = ::Twilio::TwiML::VoiceResponse.new
      # Evitar mensajes, conectamos directamente al número del cliente.
      response.dial(caller_id: from_number, answer_on_bridge: true, timeout: 30) do |dial|
        dial.number(to_number)
      end

      render xml: response.to_xml, content_type: "text/xml"
    rescue StandardError => e
      Rails.logger.error("Twilio Voice connect error: #{e.message}")
      render xml: empty_twiml_with_say("Error interno"), status: :ok
    end

    private

    def empty_twiml_with_say(message)
      ::Twilio::TwiML::VoiceResponse.new do |r|
        r.say(message: message, language: "es-MX", voice: "alice")
      end.to_xml
    end
  end
end