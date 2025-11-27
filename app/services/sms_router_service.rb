class SmsRouterService
  def self.normalize_phone(phone)
    return nil if phone.blank?

    # Remove all non-digit characters
    digits = phone.gsub(/\D/, "")

    # Handle different formats
    if digits.length == 10
      "+1#{digits}"
    elsif digits.length == 11 && digits.start_with?("1")
      "+#{digits}"
    elsif digits.length == 12 && digits.start_with?("1")
      "+#{digits}"
    else
      phone.strip
    end
  end

  def self.route_inbound_sms(from_phone, to_phone, message_body, twilio_sms_id)
    normalized_from = normalize_phone(from_phone)
    normalized_to = normalize_phone(to_phone)

    return nil if normalized_from.blank? || message_body.blank?

    # Find user by phone number (via Number model)
    number_record = Number.find_by(phone_number: normalized_to)
    user = number_record&.user

    if user.nil?
      # Try to find user by any other method if needed
      user = User.first # Fallback to first user or implement your logic
    end

    # Try to find client first
    client = Client.find_by(phone: normalized_from)

    if client
      return create_sms_from_twilio(
        twilio_sms_id: twilio_sms_id,
        from_phone: normalized_from,
        to_phone: normalized_to,
        message_body: message_body,
        user: user,
        direction: "inbound",
        client: client
      )
    end

    # Try to find contact
    contact_list = ContactList.find_by(phone: normalized_from)

    if contact_list
      return create_sms_from_twilio(
        twilio_sms_id: twilio_sms_id,
        from_phone: normalized_from,
        to_phone: normalized_to,
        message_body: message_body,
        user: user,
        direction: "inbound",
        contact_list: contact_list
      )
    end

    # Unknown number - store as string
    create_sms_from_twilio(
      twilio_sms_id: twilio_sms_id,
      from_phone: normalized_from,
      to_phone: normalized_to,
      message_body: message_body,
      user: user,
      direction: "inbound"
    )
  end

  def self.create_sms_from_twilio(twilio_sms_id:, from_phone:, to_phone:, message_body:, user:, direction:, client: nil, contact_list: nil)
    current_time = Time.current

    TextMessage.create!(
      twilio_sms_id: twilio_sms_id,
      sms_date: current_time.to_date,
      sms_time: current_time,
      user: user,
      direction: direction,
      client: client,
      contact_list: contact_list,
      message_body: message_body,
      status: "received",
      to_phone: to_phone,
      from_phone: from_phone
    )
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.error "Error creating SMS: #{e.message}"
    nil
  end

  def self.create_outbound_sms(user:, client: nil, contact_list: nil, to_phone:, message_body:)
    current_time = Time.current

    # Generate a unique ID for outbound messages
    twilio_sms_id = "outbound_#{SecureRandom.uuid}"

    TextMessage.create!(
      twilio_sms_id: twilio_sms_id,
      sms_date: current_time.to_date,
      sms_time: current_time,
      user: user,
      direction: "outbound",
      client: client,
      contact_list: contact_list,
      message_body: message_body,
      status: "pending",
      to_phone: to_phone,
      from_phone: user.numbers.active.first&.phone_number || "+1234567890" # Replace with your Twilio number
    )
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.error "Error creating outbound SMS: #{e.message}"
    nil
  end
end
