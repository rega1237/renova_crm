# frozen_string_literal: true

require "twilio-ruby"

module Twilio
  class CallbacksController < ActionController::Base
    protect_from_forgery with: :null_session
    before_action :verify_twilio_signature, only: [:voice_status]

    # Webhook de estado de Twilio para llamadas
    # Configurado con status_callback_event: ["completed"], recibiremos la duración al finalizar
    def voice_status
      Rails.logger.info("Twilio Voice status callback params: #{params.to_unsafe_h.inspect}")

      # Para <Dial> Twilio envía ambos: CallSid (parent) y DialCallSid (child)
      # Preferir el parent para actualizar el registro pre-creado y evitar duplicados
      parent_sid = params[:CallSid] || params[:call_sid]
      child_sid  = params[:DialCallSid]
      sid = parent_sid.presence || child_sid
      call_status = params[:CallStatus] || params[:call_status]
      # Para <Dial>, Twilio envía DialCallStatus y DialCallDuration.
      # Para llamadas directas (API), envía CallStatus y CallDuration.
      dial_status = params[:DialCallStatus] || params[:dial_call_status]
      dial_duration_param = params[:DialCallDuration] || params[:dial_call_duration]
      duration_param = params[:CallDuration] || dial_duration_param || params[:call_duration]
      duration = duration_param.to_i if duration_param.present?
      direction = params[:direction]

      # Determinar si la llamada fue atendida
      answered = nil
      if dial_duration_param.present?
        answered = dial_duration_param.to_i > 0
      elsif duration_param.present?
        answered = duration_param.to_i > 0
      else
        # Inferencias sin duración: considerar estados que implican conexión
        if dial_status.present?
          # 'answered' o 'completed' en Dial indican que el destinatario contestó
          answered = %w[answered completed].include?(dial_status.to_s)
        elsif call_status.present?
          # En llamadas directas, 'in-progress' o 'completed' implican que fue atendida
          answered = %w[in-progress completed].include?(call_status.to_s)
        end
      end

      if sid.blank?
        return render json: { error: "Falta CallSid" }, status: :bad_request
      end

      call = ::Call.find_by(twilio_call_id: parent_sid) || ::Call.find_by(twilio_call_id: child_sid) || ::Call.find_by(twilio_call_id: sid)
      if call
        # Actualizar duración si está disponible
        updates = {}
        updates[:duration] = duration if duration && duration >= 0
        updates[:direction] = direction if direction.present?
        updates[:answered] = answered unless answered.nil?
        updates[:status] = (dial_status || call_status) if (dial_status || call_status)
        # Rellenar user_id si el registro aún no lo tiene y podemos inferirlo
        if call.user_id.blank?
          inferred_user_id = resolve_user_id_from_callback
          updates[:user_id] = inferred_user_id if inferred_user_id.present?
        end
        # Si no teníamos fecha/hora (registros creados por otros flujos), setearlas
        updates[:call_date] ||= Date.current if call.call_date.blank?
        updates[:call_time] ||= Time.current if call.call_time.blank?

        begin
          call.update!(updates) if updates.any?
        rescue StandardError => e
          Rails.logger.error("Failed to update Call #{sid}: #{e.class} - #{e.message}")
          # No bloquear el webhook
        end
      else
        # Si no existe, intentar crearlo con información mínima
        # Podemos recibir user_id en la query string del status_callback
        user_id = resolve_user_id_from_callback
        begin
          ::Call.create!(
            twilio_call_id: parent_sid.presence || sid,
            call_date: Date.current,
            call_time: Time.current,
            user_id: user_id,
            duration: duration,
            direction: direction,
            answered: answered,
            status: (dial_status || call_status)
          )
        rescue StandardError => e
          Rails.logger.error("Failed to create Call from callback SID #{sid}: #{e.class} - #{e.message}")
        end
      end

      status_text = dial_status || call_status
      render json: { ok: true, status: status_text, duration: duration, answered: answered, direction: direction }, status: :ok
    end

    private

    def verify_twilio_signature
      begin
        signature = request.headers["X-Twilio-Signature"]
        auth_token = TWILIO_AUTH_TOKEN
        if auth_token.blank? || signature.blank?
          Rails.logger.warn("Saltando verificación de firma de Twilio: faltan TWILIO_AUTH_TOKEN o X-Twilio-Signature")
          return true
        end

        validator = ::Twilio::Security::RequestValidator.new(auth_token)
        url = request.original_url
        params_hash = request.request_parameters.merge(request.query_parameters)
        valid = validator.validate(url, params_hash, signature)
        unless valid
          Rails.logger.warn("Firma Twilio inválida para #{url}")
          render json: { error: "Solicitud no autorizada" }, status: :forbidden
        end
      rescue StandardError => e
        Rails.logger.error("Error verificando firma de Twilio: #{e.class} - #{e.message}")
        true
      end
    end

    # Intenta deducir user_id a partir de los parámetros del callback
    def resolve_user_id_from_callback
      # 1) user_id explícito en la URL de callback
      explicit = params[:user_id]
      return explicit if explicit.present?

      # 2) Desde el "From" cuando es un número Twilio en E.164
      from = params[:From].to_s
      if from.start_with?("+")
        num = ::Number.find_by(phone_number: from)
        return num.user_id if num
      end

      # 3) Desde la identidad de WebRTC (client:email)
      identity = params[:Caller].presence || params[:From].presence
      if identity.to_s.start_with?("client:")
        email = identity.to_s.sub("client:", "")
        user = ::User.find_by(email: email)
        return user.id if user
      end

      nil
    rescue StandardError
      nil
    end
  end
end