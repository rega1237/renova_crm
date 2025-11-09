# frozen_string_literal: true

require "twilio-ruby"

module Twilio
  class VoiceController < ActionController::Base
    protect_from_forgery with: :null_session
    before_action :verify_twilio_signature, only: [:connect]

    # Twilio hará una petición GET/POST a esta acción para obtener TwiML
    def connect
      # Log de diagnóstico: parámetros recibidos por el webhook
      Rails.logger.info("Twilio Voice connect params: #{params.to_unsafe_h.inspect}")

      # Detectar flujo saliente (SDK) vs entrante.
      caller_id_param = params[:caller_id]
      to_param = params[:To] || params[:to]
      called_param = params[:Called] || params[:called]
      from_param = params[:From] || params[:from]

      response = ::Twilio::TwiML::VoiceResponse.new

      if caller_id_param.present?
        # ===== Saliente desde navegador (WebRTC) =====
        to_number = to_param
        from_number = caller_id_param

        unless to_number.present? && from_number.present?
          Rails.logger.warn("Parámetros incompletos (saliente) en /twilio/voice/connect: To=#{to_number.inspect}, caller_id=#{from_number.inspect}")
          return render xml: empty_twiml_with_say("Parámetros incompletos"), status: :ok
        end

        unless from_number.to_s.match?(/\A\+\d{8,15}\z/)
          Rails.logger.warn("callerId inválido (saliente) en /twilio/voice/connect: caller_id=#{from_number.inspect}")
          return render xml: empty_twiml_with_say("callerId inválido para la llamada"), status: :ok
        end

        # Intentar obtener el user_id desde los parámetros o desde la identidad del Caller (client:email)
        user_id_param = params[:user_id].presence || find_user_id_from_identity(params[:Caller] || params[:From])
        callback_url = build_status_callback_url(user_id: user_id_param, direction: "outbound-dial")
        Rails.logger.info("Dial status_callback URL (outbound-dial): #{callback_url.inspect}")

        response.dial(caller_id: from_number, answer_on_bridge: true, timeout: 30,
                      **status_callback_opts(callback_url)) do |dial|
          dial.number(to_number)
        end

        # Registrar preventivamente el Call usando el CallSid (si disponible) para que aparezca en el listado
        begin
          sid = params[:CallSid] || params[:call_sid]
          if sid.present?
            ::Call.find_or_create_by!(twilio_call_id: sid) do |c|
              c.call_date = Date.current
              c.call_time = Time.current
              c.user_id = user_id_param
              c.direction = "outbound-dial"
              c.duration = nil
            end
          end
        rescue StandardError => e
          Rails.logger.error("No se pudo registrar llamada saliente: #{e.class} - #{e.message}")
        end
      else
        # ===== Entrante (llamadas recibidas) =====
        inbound_twilio_number = to_param || called_param
        unless inbound_twilio_number.present?
          Rails.logger.warn("Parámetros incompletos (entrante) en /twilio/voice/connect: Called/To ausente")
          return render xml: empty_twiml_with_say("Número no disponible"), status: :ok
        end

        # Determinar el usuario dueño del número Twilio llamado
        target_user = find_user_by_twilio_number(inbound_twilio_number)
        unless target_user
          Rails.logger.warn("No se encontró usuario asociado al número Twilio #{inbound_twilio_number}")
          return render xml: empty_twiml_with_say("No disponible"), status: :ok
        end

        identity = target_user.email.presence || "user-#{target_user.id}"
        callback_url = build_status_callback_url(user_id: target_user.id, direction: "inbound")
        Rails.logger.info("Dial status_callback URL (inbound): #{callback_url.inspect}")

        # Enrutar la llamada entrante al cliente (navegador) del usuario destino
        response.dial(answer_on_bridge: true, timeout: 30, **status_callback_opts(callback_url)) do |dial|
          dial.client(identity)
        end

        # Registrar preventivamente el Call usando el CallSid recibido (si disponible)
        begin
          sid = params[:CallSid] || params[:call_sid]
          if sid.present?
            ::Call.find_or_create_by!(twilio_call_id: sid) do |c|
              c.call_date = Date.current
              c.call_time = Time.current
              c.user_id = target_user.id
              c.duration = nil
            end
          end
        rescue StandardError => e
          Rails.logger.error("No se pudo registrar llamada entrante: #{e.class} - #{e.message}")
        end
      end

      # Log extra: TwiML generado para comprobar que incluye statusCallback en <Dial>
      begin
        twiml_xml = response.to_xml
        Rails.logger.info("Generated TwiML for /twilio/voice/connect (truncated): #{twiml_xml.to_s[0, 500]}...")
      rescue StandardError => e
        Rails.logger.warn("Could not serialize TwiML for logging: #{e.class} - #{e.message}")
      end
      render xml: response.to_xml, content_type: "text/xml"
    rescue StandardError => e
      Rails.logger.error("Twilio Voice connect error: #{e.message}")
      render xml: empty_twiml_with_say("Error interno"), status: :ok
    end

    private

    # Helper para construir opciones de status_callback en <Dial>
    def status_callback_opts(callback_url)
      return {} unless callback_url.present?
      {
        status_callback: callback_url,
        # Twilio espera la lista separada por espacios en XML; usamos string explícita.
        status_callback_event: "initiated ringing answered completed",
        status_callback_method: "POST"
      }
    end

    # Buscar el usuario dueño del número Twilio llamado
    def find_user_by_twilio_number(number)
      num = number.to_s.strip
      record = ::Number.find_by(phone_number: num)
      record&.user
    end

    # Construye URL absoluta del callback de estado, incluyendo metadatos
    def build_status_callback_url(user_id: nil, direction: nil)
      helpers = Rails.application.routes.url_helpers
      # Preferir la URL base del request que Twilio usó para llamarnos
      if request && request.base_url.present?
        path = helpers.twilio_voice_status_callback_path(user_id: user_id, direction: direction)
        return "#{request.base_url}#{path}"
      end
      # Fallback: utilizar host configurado (evitar placeholder "example.com")
      host = Rails.application.routes.default_url_options[:host] || Rails.application.config.action_mailer.default_url_options&.dig(:host)
      if host.present? && host != "example.com"
        return helpers.twilio_voice_status_callback_url(host: host, protocol: "https", user_id: user_id, direction: direction)
      end
      nil
    rescue StandardError => e
      Rails.logger.warn("No se pudo construir status_callback: #{e.class} - #{e.message}")
      nil
    end

    def empty_twiml_with_say(message)
      ::Twilio::TwiML::VoiceResponse.new do |r|
        r.say(message: message, language: "es-MX", voice: "alice")
      end.to_xml
    end

    # Verificación de firma de Twilio para asegurar que la petición proviene de Twilio
    def verify_twilio_signature
      begin
        signature = request.headers["X-Twilio-Signature"]
        auth_token = TWILIO_AUTH_TOKEN
        if auth_token.blank? || signature.blank?
          Rails.logger.warn("Saltando verificación de firma de Twilio: faltan TWILIO_AUTH_TOKEN o X-Twilio-Signature")
          return true
        end

        validator = ::Twilio::Security::RequestValidator.new(auth_token)
        # Twilio firma con la URL original y los parámetros del request (POST + query)
        url = request.original_url
        params = request.request_parameters.merge(request.query_parameters)
        valid = validator.validate(url, params, signature)
        unless valid
          Rails.logger.warn("Firma Twilio inválida para #{url}")
          render xml: empty_twiml_with_say("Solicitud no autorizada"), status: :forbidden
        end
      rescue StandardError => e
        Rails.logger.error("Error verificando firma de Twilio: #{e.class} - #{e.message}")
        # En caso de error inesperado, no bloquear la llamada pero registrar.
        true
      end
    end

    # Extraer user_id desde una identidad de Twilio Voice SDK (client:email)
    def find_user_id_from_identity(identity)
      return nil unless identity.present?
      str = identity.to_s
      email = if (m = str.match(/\Aclient:(.+)\z/))
                m[1]
              else
                str
              end
      ::User.find_by(email: email)&.id
    rescue StandardError
      nil
    end
  end
end