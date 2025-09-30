class Facebook::AuthorizationsController < ApplicationController
def new
  # Añadir parámetros específicos para Business Manager
  scopes = "pages_show_list,pages_read_engagement,leads_retrieval,pages_manage_metadata,business_management,read_insights"

  oauth = Koala::Facebook::OAuth.new(
    Rails.application.credentials.facebook[:app_id],
    Rails.application.credentials.facebook[:app_secret],
    facebook_auth_callback_url
  )

  # Añadir parámetros adicionales que ayudan con Business Manager
  oauth_url = oauth.url_for_oauth_code(
    permissions: scopes,
    display: "popup",
    auth_type: "rerequest", # Fuerza a mostrar todos los permisos nuevamente
    response_type: "code"
  )

  redirect_to oauth_url, allow_other_host: true
end

def create
  oauth = Koala::Facebook::OAuth.new(
    Rails.application.credentials.facebook[:app_id],
    Rails.application.credentials.facebook[:app_secret],
    facebook_auth_callback_url
  )

  begin
    user_access_token = oauth.get_access_token(params[:code])
    graph = Koala::Facebook::API.new(user_access_token)

    # Debug información del usuario y contexto
    user_info = graph.get_object("me", fields: "id,name")
    Rails.logger.info "=== INFORMACIÓN DEL USUARIO ==="
    Rails.logger.info "Usuario autenticado: #{user_info.inspect}"

    # Verificar permisos otorgados
    permissions = graph.get_connections("me", "permissions")
    granted_permissions = permissions.select { |p| p["status"] == "granted" }.map { |p| p["permission"] }
    Rails.logger.info "=== PERMISOS ==="
    Rails.logger.info "Permisos otorgados: #{granted_permissions.inspect}"

    pages = []

    # MÉTODO 1: Intentar obtener páginas del usuario directamente
    Rails.logger.info "=== MÉTODO 1: PÁGINAS DEL USUARIO ==="
    begin
      user_pages = graph.get_connections("me", "accounts")
      Rails.logger.info "Páginas del usuario: #{user_pages.count} encontradas"
      Rails.logger.info "Detalles: #{user_pages.inspect}" if user_pages.any?
      pages.concat(user_pages)
    rescue => e
      Rails.logger.error "Error en páginas del usuario: #{e.message}"
    end

    # MÉTODO 2: Obtener business accounts y sus páginas
    Rails.logger.info "=== MÉTODO 2: BUSINESS MANAGER ==="
    begin
      businesses = graph.get_connections("me", "businesses")
      Rails.logger.info "Business accounts encontrados: #{businesses.count}"
      Rails.logger.info "Business details: #{businesses.inspect}"

      businesses.each do |business|
        begin
          business_pages = graph.get_connections(business["id"], "pages")
          Rails.logger.info "Páginas en business #{business['name']}: #{business_pages.count}"
          Rails.logger.info "Detalles business pages: #{business_pages.inspect}" if business_pages.any?
          pages.concat(business_pages)
        rescue => e
          Rails.logger.error "Error obteniendo páginas del business #{business['id']}: #{e.message}"
        end
      end
    rescue => e
      Rails.logger.error "Error obteniendo businesses: #{e.message}"
    end

    # MÉTODO 3: Intentar con el business manager específico si conocemos el ID
    # (Puedes obtener el Business ID desde business.facebook.com en la URL)
    Rails.logger.info "=== MÉTODO 3: BUSINESS ESPECÍFICO ==="
    business_manager_id = "740866735767004" # Este ID se ve en tu URL del Business Manager

    begin
      # Intentar obtener páginas directamente del Business Manager
      business_pages = graph.get_connections(business_manager_id, "pages")
      Rails.logger.info "Páginas del Business Manager específico: #{business_pages.count}"
      Rails.logger.info "Detalles BM específico: #{business_pages.inspect}" if business_pages.any?
      pages.concat(business_pages)
    rescue => e
      Rails.logger.error "Error accediendo al Business Manager específico: #{e.message}"

      # Si falla, intentar obtener información del business manager
      begin
        business_info = graph.get_object(business_manager_id)
        Rails.logger.info "Info del Business Manager: #{business_info.inspect}"
      rescue => e2
        Rails.logger.error "No se puede acceder al Business Manager: #{e2.message}"
      end
    end

    # Eliminar duplicados basados en el ID de la página
    pages = pages.uniq { |page| page["id"] }

    Rails.logger.info "=== RESULTADO FINAL ==="
    Rails.logger.info "Total páginas únicas encontradas: #{pages.count}"
    Rails.logger.info "Páginas finales: #{pages.inspect}" if pages.any?

    if pages.empty?
      redirect_to settings_root_path,
        alert: "No se pudieron obtener las páginas desde Business Manager. Verifica que: 1) Tu usuario tenga permisos en el Business Manager, 2) La página esté correctamente asignada al Business Manager, 3) Los permisos de la app incluyan business_management."
    elsif pages.count == 1
      save_page_integration(pages.first)
    else
      session[:facebook_pages] = pages
      render "select_page"
    end

  rescue => e
    Rails.logger.error "=== ERROR GENERAL ==="
    Rails.logger.error "Error: #{e.class} - #{e.message}"
    Rails.logger.error e.backtrace.first(10).join("\n")
    redirect_to settings_root_path, alert: "Error: #{e.message}"
  end
end

  def save_page_selection
    selected_page_id = params[:page_id]
    pages = session[:facebook_pages]
    selected_page = pages&.find { |p| p["id"] == selected_page_id }

    if selected_page
      save_page_integration(selected_page)
    else
      redirect_to settings_root_path, alert: "Página no válida seleccionada."
    end
  end

  private

  def save_page_integration(page_data)
    oauth = Koala::Facebook::OAuth.new(
      Rails.application.credentials.facebook[:app_id],
      Rails.application.credentials.facebook[:app_secret]
    )
    page_access_token = oauth.exchange_access_token(page_data["access_token"])

    integration = FacebookIntegration.first_or_initialize
    integration.update!(
      page_id: page_data["id"],
      page_name: page_data["name"],
      access_token: page_access_token
    )

    session.delete(:facebook_pages)
    redirect_to settings_root_path, notice: "Página '#{page_data['name']}' conectada exitosamente.", status: :see_other
  end
end
