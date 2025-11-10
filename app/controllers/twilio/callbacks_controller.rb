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