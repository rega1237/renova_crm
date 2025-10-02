Rails.application.config.middleware.use OmniAuth::Builder do
  provider :google_oauth2,
           Rails.application.credentials.dig(:google_oauth2, :client_id),
           Rails.application.credentials.dig(:google_oauth2, :client_secret),
           {
             scope: "email, profile, calendar",
             access_type: "offline",
             prompt: "consent"
           }
end

OmniAuth.config.allowed_request_methods = [ :post, :get ]
OmniAuth.config.silence_get_warning = true
