Rails.application.routes.draw do
  get "pages/privacy"
  # --- Action Cable ---
  mount ActionCable.server => "/cable"

  get "clients/index"
  # --- Rutas de Autenticación ---
  resource :session
  resources :passwords, param: :token

  # --- Rutas de Administración ---
  namespace :admin do
    resources :users, only: [ :index, :new, :create, :edit, :update, :show, :destroy ]
  end

  # --- Rutas de Configuración ---
  namespace :settings do
    resources :sellers
    resources :installers
    resources :states
    resources :cities
    resources :numbers
    # La página principal del menú de configuración
    root to: "dashboard#index"
    post "import_clients", to: "dashboard#import_clients"
    get  "export_clients", to: "dashboard#export_clients"
  end

  # --- Rutas de Clientes ---
  resources :clients, only: [ :index, :show, :new, :create, :edit, :update, :destroy ] do
    resources :notes, only: [ :index, :new, :create, :destroy ]
    resources :appointments, only: [ :create, :edit, :update, :destroy ]
    member do
      patch :update_assigned_seller
      patch :update_field
    end
  end

  # --- Ruta para Flujo de Ventas ---
  get "sales_flow", to: "sales_flow#index"
  get "sales_flow/load_more", to: "sales_flow#load_more"
  get "sales_flow/counts", to: "sales_flow#counts"
  get "calendar", to: "calendar#index"
  get "appointments_list", to: "appointments_list#index"

  # --- Ruta para Actualizar Status via Drag & Drop ---
  patch "clients/:id/update_status", to: "clients#update_status", as: "update_client_status"

  # --- RUTAS PARA LA AUTORIZACIÓN DE FACEBOOK (OAuth) ---
  namespace :facebook do
    get "auth", to: "authorizations#new"
    get "auth/callback", to: "authorizations#create"
    post "save_page_selection", to: "authorizations#save_page_selection"
  end

  # --- RUTAS PARA LA AUTORIZACIÓN DE GOOGLE (OAuth) ---
  namespace :google do
    get "auth", to: "authorizations#new"
  end

  get "/auth/google_oauth2/callback", to: "google/authorizations#create"

  # --- RUTAS PARA EL WEBHOOK DE FACEBOOK ---
  namespace :api do
    resources :cities, only: [ :index ]
    resources :calls, only: [ :create ]
    # WebRTC: preparar llamada (selección de número de origen) sin iniciar llamada server-side
    post "voice/prepare", to: "voice_calls#prepare"

    # WebRTC: emisión de token para Twilio Voice SDK en el navegador
    namespace :twilio do
      post "voice/token", to: "voice_tokens#create"
    end
    namespace :facebook do
      get "webhooks", to: "webhooks#verify"
      post "webhooks", to: "webhooks#receive"
    end
  end

  # --- Rutas Principales y de Sistema ---
  get "up" => "rails/health#show", as: :rails_health_check
  get "dashboard/leads_metrics", to: "dashboard#leads_metrics"
  get "dashboard/telemarketing_metrics", to: "dashboard#telemarketing_metrics"
  get "dashboard/sellers_metrics", to: "dashboard#sellers_metrics"
  root "dashboard#index"
  # TwiML endpoint para instruir llamadas salientes desde Twilio (usado por WebRTC)
  namespace :twilio do
    get "voice/connect", to: "voice#connect"
    post "voice/connect", to: "voice#connect"
  end
end
