Rails.application.routes.draw do
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
    # La página principal del menú de configuración
    root to: "dashboard#index"
  end

  # --- Rutas Principales y de Sistema ---
  get "up" => "rails/health#show", as: :rails_health_check
  root "dashboard#index"
end
