Rails.application.routes.draw do
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
    # La página principal del menú de configuración
    root to: "dashboard#index"
  end

  # --- Rutas de Clientes ---
  resources :clients, only: [ :index, :show, :new, :create, :edit, :update, :destroy ] do
    resources :notes, only: [ :index, :new, :create, :destroy ]
  end

  # --- Ruta para Flujo de Ventas ---
  get "sales_flow", to: "sales_flow#index"

  # --- Ruta para Actualizar Status via Drag & Drop ---
  patch "clients/:id/update_status", to: "clients#update_status", as: "update_client_status"

  # --- Rutas Principales y de Sistema ---
  get "up" => "rails/health#show", as: :rails_health_check
  root "dashboard#index"
end
