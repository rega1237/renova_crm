# TextMessagesController
# Controlador administrativo para la gestión global de mensajes SMS
# Maneja: vista administrativa de todos los SMS, filtros avanzados, KPIs y métricas
# Rutas: /text_messages
class TextMessagesController < ApplicationController
  protect_from_forgery with: :null_session, only: [ :receive_webhook ]
  before_action :require_authentication, except: [ :receive_webhook ]
  before_action :set_text_message, only: [ :show ]

  PER_PAGE = 20

  def index
    @page = params[:page].to_i
    @page = 1 if @page <= 0

    @text_messages = TextMessage.includes(:client, :contact_list, :user)
                              .order(sms_time: :desc)

    # Filtros
    if params[:direction].present?
      @text_messages = @text_messages.where(direction: params[:direction])
    end

    if params[:start_date].present? && params[:end_date].present?
      start_date = Date.parse(params[:start_date])
      end_date = Date.parse(params[:end_date])
      @text_messages = @text_messages.where(sms_date: start_date..end_date)
    end

    if params[:phone].present?
      phone_filter = params[:phone].gsub(/[^0-9]/, "")
      @text_messages = @text_messages.where("from_phone LIKE :phone OR to_phone LIKE :phone", phone: "%#{phone_filter}%")
    end

    if params[:sender].present?
      sender_filter = params[:sender].downcase
      @text_messages = @text_messages.joins(:user)
                                    .where("LOWER(users.name) LIKE :sender OR LOWER(users.email) LIKE :sender", sender: "%#{sender_filter}%")
    end

    # KPIs
    @total_inbound = TextMessage.where(direction: "inbound").count
    @total_outbound = TextMessage.where(direction: "outbound").count
    @total_pending = TextMessage.where(status: "pending").count
    @today_count = TextMessage.where(sms_date: Date.current).count

    # Paginación manual
    @total_count = @text_messages.count
    @total_pages = (@total_count.to_f / PER_PAGE).ceil
    @text_messages = @text_messages.offset((@page - 1) * PER_PAGE).limit(PER_PAGE)
  end

  def show
    @client = @text_message.client
    @contact_list = @text_message.contact_list
  end

  def receive_webhook
    # Webhook para recibir SMS de Twilio
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
    @text_message = TextMessage.find(params[:id])
  end
end
