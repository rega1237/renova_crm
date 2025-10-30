# frozen_string_literal: true

require "twilio-ruby"

module Twilio
  class VoiceController < ActionController::Base
    protect_from_forgery with: :null_session

    # Twilio hará una petición GET/POST a esta acción para obtener TwiML
    def connect
      # Este endpoint es llamado por Twilio cuando el navegador inicia una llamada
      # mediante el Voice SDK (outgoing_application_sid). Los parámetros incluidos
      # en Device.connect se reciben aquí (por ejemplo: To y From).

      to_number = params[:To] || params[:to]
      from_number = params[:From] || params[:from] || params[:caller_id]

      unless to_number.present? && from_number.present?
        return render xml: empty_twiml_with_say("Parámetros incompletos"), status: :ok
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