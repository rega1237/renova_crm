require "twilio-ruby"

module Api
  module Twilio
    class VoiceTokensController < ApplicationController
      protect_from_forgery with: :null_session

      allow_unauthenticated_access only: [:create]
      before_action :resume_session
      before_action :require_current_user!

      def create
        identity = Current.user.email.presence || "user-#{Current.user.id}"

        api_key_sid = Rails.application.credentials.dig(:twilio, :api_key_sid) || ENV["TWILIO_API_KEY_SID"]
        api_key_secret = Rails.application.credentials.dig(:twilio, :api_key_secret) || ENV["TWILIO_API_KEY_SECRET"]
        account_sid = TWILIO_ACCOUNT_SID
        twiml_app_sid = Rails.application.credentials.dig(:twilio, :twiml_app_sid) || ENV["TWILIO_TWIML_APP_SID"]

        unless api_key_sid.present? && api_key_secret.present? && account_sid.present? && twiml_app_sid.present?
          return render json: { error: "Faltan credenciales de Twilio para emitir el token (API_KEY_SID/SECRET y TWIML_APP_SID)" }, status: :internal_server_error
        end

        token = ::Twilio::JWT::AccessToken.new(account_sid, api_key_sid, api_key_secret, identity: identity)
        grant = ::Twilio::JWT::AccessToken::VoiceGrant.new
        grant.outgoing_application_sid = twiml_app_sid
        grant.incoming_allow = true
        token.add_grant(grant)

        render json: { token: token.to_jwt, identity: identity }
      rescue StandardError => e
        Rails.logger.error("Error creando token de Twilio Voice: #{e.message}")
        render json: { error: "No se pudo crear el token" }, status: :internal_server_error
      end

      private

      def require_current_user!
        unless Current.user
          render json: { error: "No autorizado" }, status: :unauthorized
        end
      end
    end
  end
end