class User < ApplicationRecord
  has_secure_password
  has_many :sessions, dependent: :destroy
  has_many :numbers, dependent: :destroy
  has_one :google_integration, dependent: :destroy

  normalizes :email, with: ->(e) { e.strip.downcase }

  # Enum para los roles
  enum :rol, { telemarketing: 0, asistente: 1, admin: 2 }

  # Validaciones
  validates :email, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :name, presence: true
  validates :rol, presence: true

  # Teléfono del agente (para conectar llamadas 1:1). Opcional, pero si está presente debe ser E.164.
  validates :phone, allow_nil: true, format: { with: Number::PHONE_REGEX, message: "debe estar en formato E.164 (ej. +14155550123)" }

  before_validation :normalize_phone_us!

  private

  def normalize_phone_us!
    return if phone.blank?
    normalized = PhonyRails.normalize_number(phone, country_code: 'US')
    self.phone = normalized if normalized.present?
  rescue StandardError
    # Mantener el valor original si falla la normalización
  end
end
