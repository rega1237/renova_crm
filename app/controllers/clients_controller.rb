class ClientsController < ApplicationController
  before_action :set_sellers, only: %i[ new edit create update ]
  before_action :set_client, only: %i[ show edit update destroy calls call_details sms_message_details ]

  def index
    @clients = Client.includes(:state, :city, :prospecting_seller, :assigned_seller, :updated_by).order(:name)

    # Filtro por búsqueda: nombre o teléfono
    if params[:query].present?
      @clients = apply_query_filter(@clients)
    end

    # Filtro por status del cliente
    if params[:status].present?
      @clients = @clients.where(status: params[:status])
    end

    # Filtro por fuente
    if params[:source].present?
      @clients = @clients.where(source: params[:source])
    end

    # Filtro por estado
    if params[:state_id].present?
      @clients = @clients.where(state_id: params[:state_id])
    end

    # Filtro por ciudad (incluye opción especial 'Sin ciudad')
    if params[:city_id].present?
      if params[:city_id] == "none"
        @clients = @clients.where(city_id: nil)
      else
        @clients = @clients.where(city_id: params[:city_id])
      end
    end

    # Filtro por código postal (solo 5 dígitos válidos)
    if params[:zip_code].present?
      five = normalize_zip_param(params[:zip_code])
      if five.present?
        @clients = @clients.where(zip_code: five)
      end
    end

    # Filtro por vendedor (busca en ambos campos)
    if params[:seller_id].present?
      @clients = @clients.where(
        "prospecting_seller_id = ? OR assigned_seller_id = ?",
        params[:seller_id],
        params[:seller_id]
      )
    end

    # Filtro por rango de fechas
    if params[:date_from].present? || params[:date_to].present?
      if params[:order_by_created].present?
        begin
          from = params[:date_from].presence && Date.parse(params[:date_from].to_s).beginning_of_day
          to   = params[:date_to].presence   && Date.parse(params[:date_to].to_s).end_of_day
          if from && to
            @clients = @clients.where(created_at: from..to)
          elsif from
            @clients = @clients.where("created_at >= ?", from)
          elsif to
            @clients = @clients.where("created_at <= ?", to)
          end
        rescue ArgumentError
          # Si las fechas son inválidas, omitir el filtro
        end
      else
        @clients = @clients.by_date_range(params[:date_from], params[:date_to])
      end
    end

    if params[:order_by_created].present?
      @clients = @clients.reorder(created_at: :desc)
    else
      @clients = @clients.reorder(Arel.sql("COALESCE(updated_status_at, created_at) DESC"))
    end

    # Construir colecciones para los dropdowns filtradas por los parámetros actuales (excepto city y zip)
    base_for_filters = Client.where(nil)
    base_for_filters = apply_query_filter(base_for_filters) if params[:query].present?
    base_for_filters = base_for_filters.where(status: params[:status]) if params[:status].present?
    base_for_filters = base_for_filters.where(source: params[:source]) if params[:source].present?
    base_for_filters = base_for_filters.where(state_id: params[:state_id]) if params[:state_id].present?
    base_for_filters = base_for_filters.where(
      "prospecting_seller_id = :sid OR assigned_seller_id = :sid",
      sid: params[:seller_id]
    ) if params[:seller_id].present?
    if params[:date_from].present? || params[:date_to].present?
      if params[:order_by_created].present?
        begin
          from = params[:date_from].presence && Date.parse(params[:date_from].to_s).beginning_of_day
          to   = params[:date_to].presence   && Date.parse(params[:date_to].to_s).end_of_day
          if from && to
            base_for_filters = base_for_filters.where(created_at: from..to)
          elsif from
            base_for_filters = base_for_filters.where("created_at >= ?", from)
          elsif to
            base_for_filters = base_for_filters.where("created_at <= ?", to)
          end
        rescue ArgumentError
        end
      else
        base_for_filters = base_for_filters.by_date_range(params[:date_from], params[:date_to])
      end
    end

    city_ids = base_for_filters.where.not(city_id: nil).distinct.pluck(:city_id)
    @cities_for_filter = if params[:state_id].present?
                           City.where(id: city_ids, state_id: params[:state_id]).ordered
    else
                           City.where(id: city_ids).ordered
    end

    # Jerárquico para zipcodes: si hay ciudad, filtra por ciudad; si no, por estado; si no, todos
    zips_scope = base_for_filters.where.not(zip_code: [ nil, "" ])
    if params[:city_id].present? && params[:city_id] != "none"
      zips_scope = zips_scope.where(city_id: params[:city_id])
    elsif params[:state_id].present?
      zips_scope = zips_scope.where(state_id: params[:state_id])
    end

    @zipcodes_for_filter = zips_scope.where("zip_code ~ ?", '^\\d{5}$').distinct.order(:zip_code).pluck(:zip_code)

    # Estados disponibles: solo los que tienen clientes bajo los filtros actuales (excepto state/city/zip)
    base_for_states = Client.where(nil)
    base_for_states = apply_query_filter(base_for_states) if params[:query].present?
    base_for_states = base_for_states.where(status: params[:status]) if params[:status].present?
    base_for_states = base_for_states.where(source: params[:source]) if params[:source].present?
    base_for_states = base_for_states.where(
      "prospecting_seller_id = :sid OR assigned_seller_id = :sid",
      sid: params[:seller_id]
    ) if params[:seller_id].present?
    if params[:date_from].present? || params[:date_to].present?
      if params[:order_by_created].present?
        begin
          from = params[:date_from].presence && Date.parse(params[:date_from].to_s).beginning_of_day
          to   = params[:date_to].presence   && Date.parse(params[:date_to].to_s).end_of_day
          if from && to
            base_for_states = base_for_states.where(created_at: from..to)
          elsif from
            base_for_states = base_for_states.where("created_at >= ?", from)
          elsif to
            base_for_states = base_for_states.where("created_at <= ?", to)
          end
        rescue ArgumentError
        end
      else
        base_for_states = base_for_states.by_date_range(params[:date_from], params[:date_to])
      end
    end
    state_ids = base_for_states.where.not(state_id: nil).distinct.pluck(:state_id)
    @states_for_filter = State.where(id: state_ids).ordered
  end

  def show
    @client = Client.find(params[:id])
    # No bloquear aquí para evitar que el prefetch de Turbo marque "en uso" al pasar el mouse.
    # Solo mostrar banner si está bloqueado por otro usuario.
    if @client.presence_locked? && (!Current.user || @client.presence_lock_user_id != Current.user.id)
      begin
        other_user = User.find_by(id: @client.presence_lock_user_id)
        @client_in_use_by_name = other_user&.name || "Otro usuario"
        flash.now[:alert] = "Este cliente está en uso por #{@client_in_use_by_name}. Algunos cambios podrían estar bloqueados."
      rescue StandardError
        @client_in_use_by_name = "Otro usuario"
        flash.now[:alert] = "Este cliente está en uso por #{@client_in_use_by_name}."
      end
    end
  end

  def new
    @client = Client.new
  end

  def edit
  end

  def create
    @client = Client.new(client_params)
    if @client.save
      redirect_to clients_path, notice: "Cliente creado exitosamente."
    else
      render :new, status: :unprocessable_content
    end
  end

  def update
    if @client.update(client_params)
      redirect_to clients_path, notice: "Cliente actualizado exitosamente."
    else
      render :edit, status: :unprocessable_content
    end
  end

  def calls
    @calls = @client.calls.includes(:user, :contact_list).order(call_date: :desc, call_time: :desc)

    respond_to do |format|
      format.html { render :calls, layout: false }
      format.json do
        html_content = render_to_string(partial: "clients/calls_overlay", locals: { client: @client, calls: @calls }, formats: %i[html])
        render json: { html: html_content }
      end
    end
  end

  def call_details
    call = @client.calls.find(params[:call_id])
    unless current_user&.admin? || call.user_id == current_user&.id
      head :unauthorized and return
    end
    @call = call

    respond_to do |format|
      format.html { render :call_details, layout: false }
      format.json do
        html_content = render_to_string(partial: "clients/call_details_overlay", locals: { client: @client, call: @call }, formats: %i[html])
        render json: { html: html_content }
      end
    end
  end

  def sms_message_details
    sms = @client.text_messages.find(params[:sms_id])
    unless current_user&.admin? || sms.user_id == current_user&.id
      head :unauthorized and return
    end
    @sms = sms

    respond_to do |format|
      format.html { render :sms_message_details, layout: false }
      format.json do
        html_content = render_to_string(partial: "clients/sms_details_overlay", locals: { client: @client, sms: @sms }, formats: %i[html])
        render json: { html: html_content }
      end
    end
  end

  def update_field
    # Si el campo a actualizar es el status, delega a la acción que sí tiene el broadcast.
    if params[:field] == "status"
      return update_status
    end

    # Si el campo a actualizar es el vendedor asignado, delega a la acción que sí tiene el broadcast.
    if params[:field] == "assigned_seller_id"
      # Re-mapear los parámetros para que coincidan con lo que espera `update_assigned_seller`
      params[:client] = { assigned_seller_id: params[:assigned_seller_id] }
      return update_assigned_seller
    end

    @client = Client.find(params[:id])
    field = params[:field]
    value = params[field] || params[:value] || (params[:client] && params[:client][field])
    allowed_fields = %w[name phone email address zip_code status source state_id city_id prospecting_seller_id reasons]
    unless allowed_fields.include?(field)
      return render turbo_stream: turbo_stream.update(
        "client_#{field}_display",
        partial: "clients/field_with_error",
        locals: { error: "Campo no permitido", field: field, client: @client }
      )
    end

    update_params = { field => value }

    if %w[status source].include?(field)
      valid_values = Client.send(field.pluralize).keys
      unless valid_values.include?(value)
        return render turbo_stream: turbo_stream.update(
          "client_#{field}_display",
          partial: "clients/field_with_error",
          locals: { error: "Valor inválido para #{field}", field: field, client: @client }
        )
      end
    end

    if %w[state_id prospecting_seller_id].include?(field)
      case field
      when "state_id"
        valid_model = State.exists?(id: value) if value.present?
      when "prospecting_seller_id"
        valid_model = Seller.exists?(id: value) if value.present?
      end

      unless valid_model || value.blank?
        return render turbo_stream: turbo_stream.update(
          "client_#{field}_display",
          partial: "clients/field_with_error",
          locals: { error: "ID inválido para #{field}", field: field, client: @client }
        )
      end
    end

    if @client.update(update_params)
      @client.update_column(:updated_by_id, Current.user&.id) if Current.user

      # Emitir broadcast al Sales Flow si el campo actualizado afecta la tarjeta
      if field == "reasons"
        client_html = ApplicationController.render(
          partial: "sales_flow/client_card",
          locals: { client: @client }
        )
        ActionCable.server.broadcast(
          "sales_flow_channel",
          {
            action: "reason_updated",
            client_id: @client.id,
            client_html: client_html
          }
        )
      end

      render turbo_stream: turbo_stream.update(
        "client_#{field}_display",
        partial: "clients/field_display",
        locals: { field: field, client: @client }
      )
    else

      Rails.logger.error "Client update failed: #{@client.errors.full_messages.join(', ')}"
      render turbo_stream: turbo_stream.update(
        "client_#{field}_display",
        partial: "clients/field_with_error",
        locals: { error: @client.errors.full_messages.join(", "), field: field, client: @client }
      )
    end
  end

  def update_status
    @client = Client.find(params[:id])
    old_status = @client.status
    new_status = params[:status]

    if @client.update(status: new_status)
      # Reload para obtener los datos actualizados incluyendo updated_by
      @client.reload

      # Broadcast del cambio via ActionCable con información adicional
      ActionCable.server.broadcast(
        "sales_flow_channel",
        {
          action: "client_moved",
          client_id: @client.id,
          client_name: @client.name,
          updated_by_name: @client.updated_by&.name || "Usuario desconocido",
          old_status: old_status,
          new_status: new_status,
          updated_at: @client.updated_status_at || @client.updated_at, # Incluir timestamp
          client_html: render_to_string(
            partial: "sales_flow/client_card",
            locals: { client: @client },
            formats: [ :html ]
          )
        }
      )

      respond_to do |format|
        format.json do
          render json: {
            status: "success",
            message: "Cliente actualizado correctamente",
            updated_at: @client.updated_status_at || @client.updated_at # Para el frontend
          }
        end
        format.turbo_stream do
          render turbo_stream: turbo_stream.update(
            "client_status_display",
            partial: "clients/field_display",
            locals: { field: "status", client: @client }
          )
        end
      end
    else
      respond_to do |format|
        format.json { render json: { status: "error", errors: @client.errors.full_messages } }
        format.turbo_stream do
          render turbo_stream: turbo_stream.update(
            "client_status_display",
            partial: "clients/field_with_error",
            locals: { error: @client.errors.full_messages.join(", "), field: "status", client: @client }
          )
        end
      end
    end
  end

  def update_assigned_seller
    @client = Client.find(params[:id])
    old_assigned_seller = @client.assigned_seller

    if @client.update(assigned_seller_id: params[:client][:assigned_seller_id])
      Rails.logger.info "Update exitoso"

      # Actualizar el vendedor en las citas activas del cliente
      active_appointments = @client.appointments.where(status: "scheduled")
      active_appointments.update_all(seller_id: @client.assigned_seller_id)

      # Si hay citas activas actualizadas, broadcast calendar update
      if active_appointments.any?
        # Actualizar eventos de Google Calendar para cada cita activa
        active_appointments.each do |appointment|
          if appointment.google_event_id.present?
            UpdateGoogleEventJob.perform_later(appointment)
          end
        end

        ActionCable.server.broadcast(
          "calendar_updates",
          {
            action: "refresh_calendar",
            appointment_id: active_appointments.first.id
          }
        )
      end

      # Renderizamos el HTML de la tarjeta actualizada para el broadcast
      client_html = ApplicationController.render(
        partial: "sales_flow/client_card",
        locals: { client: @client }
      )

      ActionCable.server.broadcast(
        "sales_flow_channel",
        {
          action: "assigned_seller_updated",
          client_id: @client.id,
          new_seller_name: @client.assigned_seller&.name || "Sin asignar",
          client_html: client_html
        }
      )

      # Preparar streams para actualizar múltiples elementos
      streams = []

      # Actualizar el campo del vendedor asignado
      streams << turbo_stream.update(
        "client_assigned_seller_id_display",
        partial: "clients/field_display",
        locals: { field: "assigned_seller_id", client: @client }
      )

      # Si hay citas activas, actualizar la sección de detalles de la cita
      if active_appointments.any?
        active_appointment = active_appointments.first
        streams << turbo_stream.update(
          "appointment-details-section",
          partial: "appointments/appointment_details",
          locals: { client: @client, appointment: active_appointment }
        )
      end

      render turbo_stream: streams
    else
      render json: {
        status: "error",
        errors: @client.errors.full_messages,
        field_errors: @client.errors.messages
      }, status: :unprocessable_content
    end
  end

  def destroy
    @client.destroy
    flash.now[:notice] = "Cliente eliminado exitosamente."
    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to clients_url, notice: "Cliente eliminado exitosamente." }
    end
  end

  # ==========================
  # PRESENCE LOCK ENDPOINTS
  # ==========================
  def lock
    @client = Client.find(params[:id])
    unless Current.user
      return render json: { status: "error", message: "No autenticado" }, status: :unauthorized
    end

    if @client.lock_for!(Current.user)
      ActionCable.server.broadcast(
        "sales_flow_channel",
        {
          action: "client_opened",
          client_id: @client.id,
          user_id: Current.user.id,
          user_name: Current.user.name
        }
      )
      render json: { status: "locked", client_id: @client.id }
    else
      other_user = User.find_by(id: @client.presence_lock_user_id)
      render json: {
        status: "in_use",
        client_id: @client.id,
        by_user_id: @client.presence_lock_user_id,
        by_user_name: other_user&.name || "Otro usuario"
      }, status: :conflict
    end
  end

  def unlock
    @client = Client.find(params[:id])
    unless Current.user
      return render json: { status: "error", message: "No autenticado" }, status: :unauthorized
    end

    if @client.unlock_if_owner!(Current.user)
      ActionCable.server.broadcast(
        "sales_flow_channel",
        {
          action: "client_closed",
          client_id: @client.id,
          user_id: Current.user.id,
          user_name: Current.user.name
        }
      )
      render json: { status: "unlocked", client_id: @client.id }
    else
      render json: { status: "not_owner_or_not_locked" }, status: :unprocessable_entity
    end
  end

  def keepalive
    @client = Client.find(params[:id])
    unless Current.user
      return render json: { status: "error", message: "No autenticado" }, status: :unauthorized
    end

    if @client.keepalive_if_owner!(Current.user)
      render json: { status: "ok", client_id: @client.id, expires_at: @client.presence_lock_expires_at }
    else
      render json: { status: "not_owner_or_not_locked" }, status: :unprocessable_entity
    end
  end

  # ==========================
  # SMS METHODS
  # ==========================
  def sms_messages
    @client = Client.find(params[:id])
    @text_messages = @client.text_messages.order(sms_time: :desc)

    respond_to do |format|
      format.html { render :sms_messages, layout: false }
      format.json do
        html_content = render_to_string(
          partial: "clients/sms_overlay",
          locals: { client: @client, text_messages: @text_messages },
          formats: %i[html]
        )
        render json: { html: html_content }
      end
    end
  end

  def send_sms
    @client = Client.find(params[:id])
    message = params[:message].to_s.strip

    if message.blank?
      return render json: { success: false, error: "El mensaje no puede estar vacío" }, status: :unprocessable_entity
    end

    # Crear registro local del SMS (pendiente de envío real cuando A2P 10DLC esté aprobado)
    text_message = TextMessage.create!(
      twilio_sms_id: "local_#{SecureRandom.uuid}",
      sms_date: Date.current,
      sms_time: Time.current,
      user_id: Current.user&.id,
      direction: "outbound",
      client_id: @client.id,
      from_phone: ENV["TWILIO_PHONE_NUMBER"],
      to_phone: @client.phone,
      message_body: message,
      status: "pending"
    )

    # TODO: Implementar envío real a Twilio cuando A2P 10DLC esté aprobado
    # Por ahora solo registramos localmente

    respond_to do |format|
      format.json do
        render json: {
          success: true,
          sms: {
            id: text_message.id,
            message_body: text_message.message_body,
            direction: text_message.direction,
            sms_time: text_message.sms_time.strftime("%Y-%m-%d %H:%M:%S"),
            sender_name: text_message.sender_name
          }
        }
      end
    end
  rescue => e
    Rails.logger.error "Error al enviar SMS: #{e.message}"
    render json: { success: false, error: "Error al enviar mensaje: #{e.message}" }, status: :unprocessable_entity
  end

  private
    def set_client
      @client = Client.find(params[:id])
    end

    def set_sellers
      @sellers = Seller.order(:name)
    end

    def client_params
      params.require(:client).permit(
        :name, :phone, :email, :address, :zip_code, :state_id, :city_id,
        :status, :source, :prospecting_seller_id, :assigned_seller_id, :reasons
      )
    end

    # Aplica filtro de búsqueda por nombre o teléfono (acepta dígitos sin símbolos)
    def apply_query_filter(scope)
      q = params[:query].to_s.strip.downcase
      digits = q.gsub(/[^0-9]/, "")

      conditions = [ "LOWER(name) ILIKE :q", "phone ILIKE :q" ]
      args = { q: "%#{q}%" }

      if digits.present?
        conditions << "regexp_replace(phone, '[^0-9]+', '', 'g') LIKE :qd"
        args[:qd] = "%#{digits}%"
      end

      scope.where(conditions.join(" OR "), args)
    end

  # Normaliza un valor de filtro de ZIP: devuelve los 5 dígitos base si existen
  def normalize_zip_param(value)
    v = value.to_s.strip
    return nil if v.blank?
    if v =~ /^\d{5}$/
      v
    else
      nil
    end
  end
end
