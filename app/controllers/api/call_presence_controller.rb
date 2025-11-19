module Api
  class CallPresenceController < ApplicationController
    before_action :require_authentication

    def start
      sid = params[:call_sid].to_s.presence
      current_user.update_columns(call_busy: true, call_busy_since: Time.current, current_call_sid: sid)
      render json: { status: "busy", call_sid: sid }
    rescue StandardError => e
      Rails.logger.error("call_presence#start error: #{e.message}")
      render json: { error: "No se pudo marcar ocupado" }, status: :unprocessable_entity
    end

    def stop
      current_user.update_columns(call_busy: false, call_busy_since: nil, current_call_sid: nil)
      render json: { status: "idle" }
    rescue StandardError => e
      Rails.logger.error("call_presence#stop error: #{e.message}")
      render json: { error: "No se pudo limpiar ocupado" }, status: :unprocessable_entity
    end
  end
end