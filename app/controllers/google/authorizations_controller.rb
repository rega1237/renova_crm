class Google::AuthorizationsController < ApplicationController
  def new
    redirect_to "/auth/google_oauth2", allow_other_host: true
  end

  def create
    auth_hash = request.env["omniauth.auth"]
    credentials = auth_hash.credentials

    integration = GoogleIntegration.find_or_initialize_by(user: Current.user)
    integration.update!(
      access_token: credentials.token,
      refresh_token: credentials.refresh_token,
      expires_at: Time.at(credentials.expires_at)
    )

    redirect_to settings_root_path, notice: "Google Calendar ha sido conectado exitosamente."
  rescue => e
    Rails.logger.error "Error durante la autenticación con Google: #{e.message}"
    redirect_to settings_root_path, alert: "Hubo un error al conectar con Google Calendar. Por favor, intenta de nuevo."
  end
end
