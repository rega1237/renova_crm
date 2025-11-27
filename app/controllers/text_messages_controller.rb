# TextMessagesController
# Controlador administrativo para la gestión global de mensajes SMS
# Maneja: vista administrativa de todos los SMS, filtros avanzados, KPIs y métricas
# Rutas: /text_messages
class TextMessagesController < ApplicationController
  before_action :require_authentication
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
    # TODO: Implementar cuando configuremos Twilio
    head :ok
  end

  private

  def set_text_message
    @text_message = TextMessage.find(params[:id])
  end
end
