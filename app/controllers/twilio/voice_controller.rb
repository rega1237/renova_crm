# frozen_string_literal: true

require "twilio-ruby"

module Twilio
  class VoiceController < ActionController::Base
    # NOTA: Usamos protect_from_forgery con :null_session para APIs, pero
    # la verificación de firma de Twilio es la protección real aquí.
    protect_from_forgery with: :null_session

    # Verificamos la firma de Twilio para asegurar que las peticiones son legítimas.
    before_action :verify_twilio_signature, only: %i[connect status]

    # Acción llamada por Twilio para obtener el TwiML que define el flujo de la llamada.
    def connect
      # Log para depuración.
      Rails.logger.info("Twilio Voice connect params: #{params.to_unsafe_h.inspect}")

      response = ::Twilio::TwiML::VoiceResponse.new

      # El parámetro `caller_id` nos lo envía nuestro frontend (call_controller.js)
      # para indicar que es una llamada saliente desde el navegador.
      if params[:caller_id].present?
        handle_outbound_call(response)
      else
        handle_inbound_call(response)
      end

      render xml: response.to_xml, content_type: "text/xml"
    rescue StandardError => e
      Rails.logger.error("Twilio Voice connect error: #{e.message}\n#{e.backtrace.join("\n")}")
      render xml: empty_twiml_with_say("Error interno en la aplicación."), status: :ok
    end

    # --- NUEVA ACCIÓN PARA EL WEBHOOK ---
    # Esta acción recibe la notificación del estado final de la llamada.
    def status
      Rails.logger.info("Twilio Voice status callback params: #{params.to_unsafe_h.inspect}")

      # El `CallSid` aquí es el de la llamada "padre" (la que se inició desde el navegador).
      parent_call_sid = params[:CallSid]
      call_record = ::Call.find_by(twilio_call_id: parent_call_sid)

      unless call_record
        Rails.logger.warn("No se encontró registro de llamada para CallSid: #{parent_call_sid}")
        return head :not_found
      end

      # Extraemos los datos importantes del webhook.
      # `DialCallStatus` nos dice el resultado de la llamada al número externo.
      status = params[:DialCallStatus]
      duration = params[:DialCallDuration]
      answered = (status == "completed")

      # También recuperamos el client_id que pasamos en la URL del callback.
      client_id = params[:client_id].presence

      # Actualizamos nuestro registro en la base de datos.
      call_record.update!(
        answered: answered,
        duration: duration.to_i,
        status: status,
        client_id: client_id
      )

      Rails.logger.info("Llamada #{call_record.id} actualizada: answered=#{answered}, duration=#{duration}, client_id=#{client_id}")

      head :ok
    rescue StandardError => e
      Rails.logger.error("Error en status callback de Twilio: #{e.message}\n#{e.backtrace.join("\n")}")
      head :internal_server_error
    end

    private

    # Maneja llamadas salientes (navegador -> Twilio -> Teléfono)
    def handle_outbound_call(response)
      to_number = params[:To]
      from_number = params[:caller_id]
      client_id = params[:client_id].presence
      user = find_user_from_identity(params[:From])

      # Construimos la URL del webhook, ahora pasando también el client_id.
      callback_url = build_status_callback_url(client_id: client_id)

      response.dial(caller_id: from_number, answer_on_bridge: true, **status_callback_opts(callback_url)) do |dial|
        dial.number(to_number)
      end

      # Creamos el registro inicial de la llamada.
      create_initial_call_record(params[:CallSid], user, client_id, "outbound-dial")
    end

    # Maneja llamadas entrantes (Teléfono -> Twilio -> Navegador)
    def handle_inbound_call(response)
      target_user = find_user_by_twilio_number(params[:To])
      unless target_user
        response.say(message: "Número no disponible.", language: "es-MX")
        return
      end

      identity = target_user.email.presence || "user-#{target_user.id}"
      callback_url = build_status_callback_url # No hay cliente en llamadas entrantes directas.

      response.dial(answer_on_bridge: true, **status_callback_opts(callback_url)) do |dial|
        dial.client(identity)
      end

      create_initial_call_record(params[:CallSid], target_user, nil, "inbound")
    end

    # Crea el registro en la BD al iniciar la llamada.
    def create_initial_call_record(sid, user, client_id, direction)
      return if sid.blank? || user.blank?

      ::Call.find_or_create_by!(twilio_call_id: sid) do |c|
        c.call_date = Date.current
        c.call_time = Time.current
        c.user = user
        c.client_id = client_id
        c.direction = direction
        c.answered = false # Estado inicial
        c.duration = 0     # Estado inicial
      end
    rescue ActiveRecord::RecordInvalid => e
      Rails.logger.error("No se pudo crear el registro de llamada inicial: #{e.message}")
    end

    # Opciones para el atributo statusCallback del TwiML <Dial>.
    def status_callback_opts(callback_url)
      return {} unless callback_url.present?

      {
        status_callback: callback_url,
        # Forzamos POST explícito para evitar defaults y cumplir con proxies intermedios.
        # Removemos status_callback_event por ahora porque Twilio Console está
        # advirtiendo (12200) que ese atributo no está permitido en <Dial> y
        # al parecer ignora el statusCallback cuando se incluye.
        # Con sólo status_callback, Twilio debe enviar al menos el evento
        # "completed" con DialCallStatus/DialCallDuration, suficiente para
        # actualizar answered y duration en nuestro Callback.
        status_callback_method: "POST"
      }
    end

    # Buscar el usuario dueño del número Twilio llamado
    def find_user_by_twilio_number(number)
      num = number.to_s.strip
      record = ::Number.find_by(phone_number: num)
      record&.user
    end

    # Construye la URL absoluta para el webhook.
    def build_status_callback_url(client_id: nil)
      helpers = Rails.application.routes.url_helpers
      # Pasamos los IDs que necesitemos para identificar la llamada.
      # El `user_id` ya no es necesario si lo asociamos al crear el registro.
      helpers.twilio_voice_status_url(
        host: request.host,
        protocol: request.protocol,
        client_id: client_id
      )
    rescue StandardError => e
      Rails.logger.warn("No se pudo construir status_callback_url: #{e.message}")
      nil
    end

    # Busca un usuario por el número de Twilio al que se llamó.
    def find_user_by_twilio_number(number)
      ::Number.find_by(phone_number: number.to_s.strip)&.user
    end

    # Busca un usuario a partir de la identidad del cliente Twilio (p.ej., "client:admin@renova.com").
    def find_user_from_identity(identity)
      return nil unless identity.present?
      email = identity.match(/\Aclient:(.+)\z/i)&.captures&.first
      ::User.find_by(email: email) if email
    end

    # TwiML de respuesta para errores.
    def empty_twiml_with_say(message)
      ::Twilio::TwiML::VoiceResponse.new do |r|
        r.say(message: message, language: "es-MX", voice: "alice")
      end.to_xml
    end

    # Verificación de la firma de la petición de Twilio.
    def verify_twilio_signature
      auth_token = ENV["TWILIO_AUTH_TOKEN"]
      return if auth_token.blank? # No verificar si no hay token configurado.

      validator = ::Twilio::Security::RequestValidator.new(auth_token)
      url = request.original_url
      params = request.request_parameters
      signature = request.headers["X-Twilio-Signature"]

      unless validator.validate(url, params, signature)
        render xml: empty_twiml_with_say("Solicitud no autorizada."), status: :forbidden
      end
    end
  end
end
