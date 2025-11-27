class TextMessage < ApplicationRecord
  belongs_to :user
  belongs_to :client, optional: true
  belongs_to :contact_list, optional: true

  validates :twilio_sms_id, presence: true, uniqueness: true
  validates :sms_date, presence: true
  validates :sms_time, presence: true
  validates :user, presence: true
  validates :direction, inclusion: { in: %w[inbound outbound] }

  validates :message_body, presence: true

  scope :by_direction, ->(dir) { where(direction: dir) if dir.present? }
  scope :by_user, ->(user_id) { where(user_id: user_id) if user_id.present? }
  scope :between_dates, ->(start_date, end_date) {
    if start_date.present? && end_date.present?
      where(sms_date: start_date.to_date..end_date.to_date)
    elsif start_date.present?
      where("sms_date >= ?", start_date.to_date)
    elsif end_date.present?
      where("sms_date <= ?", end_date.to_date)
    end
  }
  scope :from_unknown_number, -> { where(client_id: nil, contact_list_id: nil) }
  scope :from_client, -> { where.not(client_id: nil) }
  scope :from_contact, -> { where.not(contact_list_id: nil) }

  def from_known_source?
    client_id.present? || contact_list_id.present?
  end

  def sender_name
    if client_id.present?
      client&.name || "Cliente desconocido"
    elsif contact_list_id.present?
      contact_list&.name || "Contacto desconocido"
    else
      from_phone
    end
  end

  def conversation_key
    if client_id.present?
      "client_#{client_id}"
    elsif contact_list_id.present?
      "contact_#{contact_list_id}"
    else
      "phone_#{from_phone.gsub(/\D/, '')}"
    end
  end

  private

  validate :client_or_contact_exclusive

  def client_or_contact_exclusive
    if client_id.present? && contact_list_id.present?
      errors.add(:base, "El SMS no puede pertenecer a cliente y contacto a la vez")
    end
  end
end
