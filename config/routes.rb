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
    resources :zipcodes
    resources :numbers
    resources :location_imports, only: [ :new, :create ]
    # La página principal del menú de configuración
    root to: "dashboard#index"
    post "import_clients", to: "dashboard#import_clients"
    get  "export_clients", to: "dashboard#export_clients"
    # Deduplication actions (trigger jobs)
    post "dedupe_clients", to: "dashboard#dedupe_clients"
    post "dedupe_clients_dry_run", to: "dashboard#dedupe_clients_dry_run"
    # Progreso en tiempo real (usado para importaciones)
    get  "progress", to: "dashboard#progress", as: :progress
  end

  # --- Rutas de Clientes ---
  resources :clients, only: [ :index, :show, :new, :create, :edit, :update, :destroy ] do
    resources :notes, only: [ :index, :new, :create, :destroy ]
    resources :appointments, only: [ :create, :edit, :update, :destroy ]
    member do
      patch :update_assigned_seller
      patch :update_field
      post :lock
      post :unlock
      post :keepalive
    end
  end

  # --- Rutas de Contact Lists ---
  resources :contact_lists

  # --- Ruta para Flujo de Ventas ---
  get "sales_flow", to: "sales_flow#index"
  get "sales_flow/load_more", to: "sales_flow#load_more"
  get "sales_flow/counts", to: "sales_flow#counts"
  get "calendar", to: "calendar#index"
  get "appointments_list", to: "appointments_list#index"
  # --- Llamadas ---
  resources :calls, only: [ :index, :show, :new, :create, :edit, :update ] do
    member do
      get :recording
    end
  end

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
    get "lookup/caller", to: "lookups#caller"
    resources :cities, only: [ :index ]
    resources :zipcodes, only: [ :index ]
    resources :calls, only: [ :create ]
    # WebRTC: preparar llamada (selección de número de origen) sin iniciar llamada server-side
    post "voice/prepare", to: "voice_calls#prepare"
    # WebRTC: preparar llamada para ContactList
    post "voice/contact_list/prepare", to: "contact_list_voice_calls#prepare"

    # WebRTC: emisión de token para Twilio Voice SDK en el navegador
    namespace :twilio do
      post "voice/token", to: "voice_tokens#create"
    end
    # Call presence (ocupación de llamadas)
    post "call_presence/start", to: "call_presence#start"
    post "call_presence/stop",  to: "call_presence#stop"
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
    # Webhook de estado (duración/completado)
    post "voice/status_callback", to: "callbacks#voice_status", as: :voice_status_callback
    # Captura también GET por si Twilio (o proxies) lo invocan así por configuración
    get  "voice/status_callback", to: "callbacks#voice_status"
    # Webhook de estado de grabación
    post "voice/recording_status_callback", to: "callbacks#recording_status", as: :recording_status_callback
    get  "voice/recording_status_callback", to: "callbacks#recording_status"
  end

  if Rails.env.test?
    get "test_login/:id", to: "sessions#test_login", as: :test_login
  end
end
