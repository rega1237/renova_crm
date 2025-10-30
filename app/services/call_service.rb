# frozen_string_literal: true

require "twilio-ruby"

class CallService
  Result = Struct.new(:success, :sid, :status, :error, keyword_init: true)

  def initialize(client:, to_number:, from_number:, user:, twilio_client: nil)
    @client_record = client
    @to_number = to_number
    @from_number = from_number
    @user = user
    @twilio_client = twilio_client
  end

  def call!
    # Normalizar ambos números asumiendo US
    @to_number = normalize_us(@to_number)
    @from_number = normalize_us(@from_number)

    unless valid_numbers?
      return Result.new(success: false, error: "Números inválidos. Use formato E.164 (+123456789)")
    end

    twilio = @twilio_client || Twilio::REST::Client.new(TWILIO_ACCOUNT_SID, TWILIO_AUTH_TOKEN)

    # Generar URL de TwiML que conectará al cliente con el usuario (agente) mediante <Dial>
    connect_url = build_connect_url(@client_record, @user, @from_number)

    response = twilio.calls.create(
      from: @from_number,
      to: @to_number,
      url: connect_url,
      method: 'GET'
    )

    log_note!("Llamada iniciada a #{@to_number} desde #{@from_number}. SID: #{response.sid}. Estado: #{response.status}.")

    Result.new(success: true, sid: response.sid, status: response.status)
  rescue StandardError => e
    Rails.logger.error("Twilio call failed: #{e.class} - #{e.message}")
    log_note!("Error al iniciar llamada a #{@to_number} desde #{@from_number}: #{e.message}")
    Result.new(success: false, error: e.message)
  end

  private

  def valid_numbers?
    regex = Number::PHONE_REGEX
    @to_number.to_s.match?(regex) && @from_number.to_s.match?(regex)
  end

  def normalize_us(number)
    return number if number.nil?
    PhonyRails.normalize_number(number, country_code: 'US')
  rescue StandardError
    number
  end

  def log_note!(text)
    return unless @client_record && @user
    Note.create!(client: @client_record, created_by: @user, text: text)
  rescue StandardError => e
    Rails.logger.error("Failed to record call note: #{e.message}")
  end
end
  def build_connect_url(client, user, caller_id)
    # Twilio necesita una URL pública y completa. Usamos APP_HOST para construirla.
    host = ENV['APP_HOST'] || Rails.application.routes.default_url_options[:host]
    Rails.application.routes.url_helpers.twilio_voice_connect_url(
      host: host,
      client_id: client.id,
      user_id: user.id,
      caller_id: caller_id
    )
  end