# frozen_string_literal: true

module Twilio
  class CallbacksController < ActionController::Base
    # Deshabilitamos la protección CSRF para webhooks, ya que vienen de un servicio externo.
    # La verificación de firma de Twilio es nuestra seguridad.
    protect_from_forgery with: :null_session

    # Verificamos la firma de Twilio para asegurar que las peticiones son legítimas.
    before_action :verify_twilio_signature

    # Acción que recibe la notificación del estado final de la llamada.
    def voice_status
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

      # Recuperamos IDs que pudimos pasar en la URL del callback.
      client_id = params[:client_id].presence
      contact_list_id = params[:contact_list_id].presence

      # Actualizamos nuestro registro en la base de datos.
      updates = {
        answered: answered,
        duration: duration.to_i,
        status: status
      }
      # Asignar únicamente si existen para no romper FK
      updates[:client_id] = client_id if client_id && ::Client.exists?(client_id)
      updates[:contact_list_id] = contact_list_id if contact_list_id && ::ContactList.exists?(contact_list_id)

      call_record.update!(updates)

      Rails.logger.info("Llamada #{call_record.id} actualizada: answered=#{answered}, duration=#{duration}, client_id=#{client_id}, contact_list_id=#{contact_list_id}")
      # Twilio espera TwiML en la URL de `action` del <Dial> para continuar el flujo
      # después de finalizar la marcación. Si respondemos vacío, Twilio registra
      # el error 12100 (Document parse failure). Para evitarlo, devolvemos un
      # Response vacío válido.
      render xml: "<Response></Response>", content_type: "text/xml", status: :ok
    rescue StandardError => e
      Rails.logger.error("Error en status callback de Twilio: #{e.message}\n#{e.backtrace.join("\n")}")
      head :internal_server_error
    end

    # Acción que recibe la notificación del estado de la grabación.
    def recording_status
      Rails.logger.info("Twilio Recording status callback params: #{params.to_unsafe_h.inspect}")

      parent_call_sid = params[:parent_sid]
      call_record = ::Call.find_by(twilio_call_id: parent_call_sid)

      unless call_record
        Rails.logger.warn("No se encontró registro de llamada para parent_sid: #{parent_call_sid}")
        return render xml: "<Response></Response>", content_type: "text/xml", status: :ok
      end

      recording_sid = params[:RecordingSid]
      recording_status = params[:RecordingStatus]
      recording_duration = params[:RecordingDuration].to_i if params[:RecordingDuration].present?

      updates = {
        recording_sid: recording_sid,
        recording_status: recording_status,
        recording_duration: recording_duration
      }.compact

      call_record.update!(updates)

      Rails.logger.info("Grabación actualizada para llamada #{call_record.id}: sid=#{recording_sid}, status=#{recording_status}, duration=#{recording_duration}")
      render xml: "<Response></Response>", content_type: "text/xml", status: :ok
    rescue StandardError => e
      Rails.logger.error("Error en recording status callback de Twilio: #{e.message}\n#{e.backtrace.join("\n")}")
      render xml: "<Response></Response>", content_type: "text/xml", status: :ok
    end

    private

    # Verificación de la firma de la petición de Twilio.
    def verify_twilio_signature
      auth_token = ENV["TWILIO_AUTH_TOKEN"]
      return if auth_token.blank? # No verificar si no hay token configurado.

      validator = ::Twilio::Security::RequestValidator.new(auth_token)
      url = request.original_url
      # Para POST usamos los parámetros del cuerpo; para GET usamos los de la query
      params = request.post? ? request.request_parameters : request.query_parameters
      signature = request.headers["X-Twilio-Signature"]

      unless validator.validate(url, params, signature)
        Rails.logger.warn("Twilio signature inválida: url=#{url}, method=#{request.method}, params=#{params.inspect}")
        render xml: "<Response><Say>Solicitud no autorizada.</Say></Response>", status: :forbidden
      end
    end
  end
end
