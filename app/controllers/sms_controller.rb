# SmsController
# Controlador principal para la gestión de mensajes SMS del usuario actual
# Maneja: vista personalizada de SMS, dashboard de estadísticas, y webhook de Twilio
# Rutas: /sms
class SmsController < ApplicationController
  before_action :require_authentication
  before_action :authorize_admin, only: [ :index, :show ]
  before_action :set_text_message, only: [ :show ]

  PER_PAGE = 20

  def index
    @page = params[:page].to_i
    @page = 1 if @page <= 0

    @text_messages = current_user_text_messages
                    .order(sms_date: :desc, sms_time: :desc)
                    .offset((@page - 1) * PER_PAGE)
                    .limit(PER_PAGE)

    @total_sms = current_user_text_messages.count
    @inbound_sms = current_user_text_messages.by_direction("inbound").count
    @outbound_sms = current_user_text_messages.by_direction("outbound").count
    @unknown_sms = current_user_text_messages.from_unknown_number.count
    @client_sms = current_user_text_messages.from_client.count
    @contact_sms = current_user_text_messages.from_contact.count

    # Variables de paginación
    @total_count = @total_sms
    @total_pages = (@total_count.to_f / PER_PAGE).ceil

    respond_to do |format|
      format.html
      format.json { render json: @text_messages }
    end
  end

  def show
    respond_to do |format|
      format.html
      format.json { render json: @text_message }
    end
  end

  def receive_webhook
    # This will be called by Twilio webhook
    from_phone = params[:From]
    to_phone = params[:To]
    message_body = params[:Body]
    twilio_sms_id = params[:MessageSid]

    if from_phone.present? && message_body.present?
      text_message = SmsRouterService.route_inbound_sms(from_phone, to_phone, message_body, twilio_sms_id)

      if text_message
        render xml: { status: "success" }.to_xml(root: "Response")
      else
        render xml: { status: "error" }.to_xml(root: "Response"), status: :unprocessable_entity
      end
    else
      render xml: { status: "error", message: "Missing required parameters" }.to_xml(root: "Response"), status: :bad_request
    end
  end

  private

  def set_text_message
    @text_message = current_user_text_messages.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    redirect_to sms_index_path, alert: "Mensaje no encontrado"
  end

  def current_user_text_messages
    if current_user.admin?
      TextMessage.all
    else
      TextMessage.by_user(current_user.id)
    end
  end
end
