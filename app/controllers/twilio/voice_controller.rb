# frozen_string_literal: true

require "twilio-ruby"

module Twilio
  class VoiceController < ActionController::Base
    protect_from_forgery with: :null_session

    # La verificación de firma ahora solo se necesita para la acción connect en este controlador.
    before_action :verify_twilio_signature, only: :connect

    # Acción llamada por Twilio para obtener el TwiML que define el flujo de la llamada.
    def connect
      Rails.logger.info("Twilio Voice connect params: #{params.to_unsafe_h.inspect}")

      response = ::Twilio::TwiML::VoiceResponse.new

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

    private

    # Maneja llamadas salientes (navegador -> Twilio -> Teléfono)
    def handle_outbound_call(response)
      to_number = params[:To]
      from_number = params[:caller_id]
      client_id = params[:client_id].presence
      contact_list_id = params[:contact_list_id].presence
      user = find_user_from_identity(params[:From])

      # Construimos la URL del webhook, pasando también los IDs si existen.
      callback_url = build_status_callback_url(client_id: client_id, contact_list_id: contact_list_id)
      Rails.logger.info("[Twilio Voice] status callback URL (outbound): #{callback_url}")
      opts = status_callback_opts(callback_url)
      Rails.logger.info("[Twilio Voice] Dial options (outbound): #{opts.inspect}")

      response.dial(caller_id: from_number, answer_on_bridge: true, **opts) do |dial|
        dial.number(to_number)
      end

      # Creamos el registro inicial de la llamada.
      create_initial_call_record(params[:CallSid], user, client_id, contact_list_id, "outbound-dial")
    end

    # Maneja llamadas entrantes (Teléfono -> Twilio -> Navegador)
    def handle_inbound_call(response)
      target_user = find_user_by_twilio_number(params[:To])
      unless target_user
        response.say(message: "Número no disponible.", language: "es-MX")
        return
      end

      identity = target_user.email.presence || "user-#{target_user.id}"
      # Resolver el llamante (cliente o contacto) según el número que llama (params[:From])
      from_number = params[:From].to_s.strip
      resolved_client = resolve_by_phone(::Client, from_number)
      resolved_contact = resolved_client ? nil : resolve_by_phone(::ContactList, from_number)
      client_id = resolved_client&.id
      contact_list_id = resolved_contact&.id

      # Preparar callback URL incluyendo ids si se resolvieron
      callback_url = build_status_callback_url(client_id: client_id, contact_list_id: contact_list_id)
      Rails.logger.info("[Twilio Voice] status callback URL (inbound): #{callback_url}")
      opts = status_callback_opts(callback_url)
      Rails.logger.info("[Twilio Voice] Dial options (inbound): #{opts.inspect}")

      response.dial(answer_on_bridge: true, **opts) do |dial|
        dial.client(identity: identity)
      end

      # Crear registro inicial de la llamada, asignando cliente/contacto si se resolvió.
      # Si no se resolvió, guardar el número en caller_phone para referencia futura.
      unresolved_phone = (client_id || contact_list_id) ? nil : normalize_phone_for_storage(from_number)
      create_initial_call_record(params[:CallSid], target_user, client_id, contact_list_id, "inbound", caller_phone: unresolved_phone)
    end

    # Crea el registro en la BD al iniciar la llamada.
    def create_initial_call_record(sid, user, client_id, contact_list_id, direction, caller_phone: nil)
      return if sid.blank? || user.blank?

      ::Call.find_or_create_by!(twilio_call_id: sid) do |c|
        c.call_date = Date.current
        c.call_time = Time.current
        c.user = user
        # Asignar cliente/contacto solo si existen para evitar violaciones de FK
        c.client_id = (client_id if client_id && ::Client.exists?(client_id))
        c.contact_list_id = (contact_list_id if contact_list_id && ::ContactList.exists?(contact_list_id))
        c.caller_phone = (caller_phone if caller_phone.present?)
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

      # TwiML correcto: usar action y method en <Dial> para recibir DialCallStatus/DialCallDuration
      {
        action: callback_url,
        method: "POST"
      }
    end

    # Construye la URL absoluta para el webhook.
    def build_status_callback_url(client_id: nil, contact_list_id: nil)
      helpers = Rails.application.routes.url_helpers
      # Usamos el helper correcto que coincide con tu archivo de rutas.
      helpers.twilio_voice_status_callback_url(
        host: request.host,
        protocol: request.protocol,
        client_id: client_id,
        contact_list_id: contact_list_id
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

    # --- Resolución de llamante por número ---
    def resolve_by_phone(klass, raw_phone)
      normalized = normalize_phone_for_storage(raw_phone)
      digits = raw_phone.to_s.gsub(/[^0-9]/, "")
      scope = klass.where.not(phone: [ nil, "" ])
      # Exactos primero
      rec = scope.where(phone: normalized).first if normalized.present?
      return rec if rec
      rec = scope.where(phone: digits).first if digits.present?
      return rec if rec
      # Sufijo (últimos 10/7 dígitos) limpiando no-dígitos
      return nil if digits.blank?
      last10 = digits[-10..]
      last7  = digits[-7..]
      begin
        if last10.present?
          rec = scope.where("regexp_replace(phone, '[^0-9]', '', 'g') LIKE ?", "%#{last10}").first
          return rec if rec
        end
        if last7.present?
          rec = scope.where("regexp_replace(phone, '[^0-9]', '', 'g') LIKE ?", "%#{last7}").first
          return rec if rec
        end
      rescue
        cleaned = scope.map { |r| [ r, r.phone.to_s.gsub(/[^0-9]/, "") ] }
        if last10.present?
          rec = cleaned.find { |(_, digits_db)| digits_db.end_with?(last10) }&.first
          return rec if rec
        end
        if last7.present?
          rec = cleaned.find { |(_, digits_db)| digits_db.end_with?(last7) }&.first
          return rec if rec
        end
      end
      nil
    end

    def normalize_phone_for_storage(str)
      s = str.to_s.strip
      return s.gsub(/\s+/, "") if s.start_with?("+")
      begin
        normalized = PhonyRails.normalize_number(s, country_code: DEFAULT_PHONE_COUNTRY)
        normalized.presence || s
      rescue
        s
      end
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
        render xml: "<Response><Say>Solicitud no autorizada.</Say></Response>", status: :forbidden
      end
    end
  end
end
