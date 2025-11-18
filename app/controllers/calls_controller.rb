class CallsController < ApplicationController
  before_action :set_call, only: [ :show, :edit, :update, :recording ]
  before_action :authorize_call_access, only: [ :show, :edit, :update, :recording ]

  PER_PAGE = 20

  def index
    is_admin = current_user&.admin?
    is_telemarketing = current_user&.telemarketing?

    @users = User.order(:name)
    # Role-based user filter: admins can pick any user; telemarketing is forced to current_user
    if is_admin
      @user_id = params[:user_id]
    else
      # Log any attempt to view other users' data via params
      if params[:user_id].present? && params[:user_id].to_i != current_user&.id
        log_unauthorized_attempt(message: "Intento de filtrar llamadas de otro usuario")
      end
      @user_id = current_user&.id
    end
    @start_date = params[:start_date]
    @end_date = params[:end_date]
    # Filtro por "atendida" disponible para admin y telemarketing (sobre su propio set)
    @answered = params[:answered]
    @direction = params[:direction]
    @page = params[:page].to_i
    @page = 1 if @page <= 0

    # Base scope (preload de asociaciones para evitar N+1)
    calls = Call.includes(:client, :contact_list)
    calls = calls.by_user(@user_id)
    calls = calls.between_dates(@start_date, @end_date)
    calls = calls.by_direction(@direction)
    # Filtro por atendida basado en el campo answered
    case @answered
    when "yes"
      calls = calls.answered
    when "no"
      calls = calls.unanswered
    end
    calls = calls.order(call_date: :desc, call_time: :desc)

    # KPI counters (computed on the filtered scope, not paginated)
    @total_count = calls.count
    answered_condition = "answered = TRUE OR (answered IS NULL AND COALESCE(duration, 0) > 0)"
    unanswered_condition = "answered = FALSE OR (answered IS NULL AND COALESCE(duration, 0) = 0)"
    @answered_count = calls.where(Arel.sql(answered_condition)).count
    @unanswered_count = calls.where(Arel.sql(unanswered_condition)).count
    @total_pages = (@total_count.to_f / PER_PAGE).ceil
    @calls = calls.offset((@page - 1) * PER_PAGE).limit(PER_PAGE)
  end

  def show
  end

  def new
    @call = Call.new(call_date: Date.current, call_time: Time.current)
  end

  def create
    @call = Call.new(call_params)
    if @call.save
      redirect_to @call, notice: "Llamada registrada correctamente"
    else
      flash.now[:alert] = "No se pudo guardar la llamada. Revisa los errores."
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @call.update(call_params)
      redirect_to @call, notice: "Llamada actualizada correctamente"
    else
      flash.now[:alert] = "No se pudo actualizar la llamada. Revisa los errores."
      render :edit, status: :unprocessable_entity
    end
  end

  def recording
    unless @call.recording_sid.present?
      head :not_found and return
    end

    account_sid = ENV["TWILIO_ACCOUNT_SID"].to_s
    auth_token  = ENV["TWILIO_AUTH_TOKEN"].to_s
    if account_sid.blank? || auth_token.blank?
      head :service_unavailable and return
    end

    client = Twilio::REST::Client.new(account_sid, auth_token)
    begin
      rec = client.api.v2010.accounts(account_sid).recordings(@call.recording_sid).fetch
      base_uri = rec.uri.to_s.gsub('.json', '')
      media_url = "https://api.twilio.com#{base_uri}.mp3"
      resp = client.http_client.request('GET', media_url)
      data = resp.body
      send_data data, type: 'audio/mpeg', disposition: 'inline'
    rescue => e
      Rails.logger.error("Error obteniendo grabación Twilio: #{e.message}")
      head :bad_gateway
    end
  end

  private

  def set_call
    @call = Call.find(params[:id])
  end

  # Role-based authorization for accessing individual calls
  def authorize_call_access
    return if current_user&.admin?
    if @call.user_id != current_user&.id
      log_unauthorized_attempt(message: "Acceso no autorizado a llamada de otro usuario")
      redirect_to calls_path, alert: "Acceso no autorizado"
    end
  end

  def call_params
    params.require(:call).permit(:twilio_call_id, :call_date, :call_time, :user_id, :duration, :client_id, :contact_list_id, :recording_sid, :recording_status, :recording_duration)
  end
end
