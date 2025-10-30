# frozen_string_literal: true

class Number < ApplicationRecord
  belongs_to :user

  enum :status, { inactive: 0, active: 1 }

  # E.164 estricto: +<country code><subscriber number> (hasta 15 dígitos)
  PHONE_REGEX = /\A\+[1-9]\d{1,14}\z/

  # Normaliza el número a E.164 asumiendo país por defecto: US
  before_validation :normalize_phone_number_us!

  validates :phone_number, presence: true,
                           uniqueness: true,
                           format: { with: PHONE_REGEX, message: "debe estar en formato E.164 (ej. +14155550123)" }
  validates :state, presence: true
  validates :user_id, presence: true

  scope :for_state, ->(state_name) { where(state: state_name) }
  scope :owned_by, ->(user) { where(user_id: user.id) }

  private

  def normalize_phone_number_us!
    return if phone_number.blank?
    normalized = PhonyRails.normalize_number(phone_number, country_code: 'US')
    self.phone_number = normalized if normalized.present?
  rescue StandardError
    # Si falla la normalización, la validación mostrará el error de formato
  end
end