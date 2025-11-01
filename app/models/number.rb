# frozen_string_literal: true

class Number < ApplicationRecord
  belongs_to :user

  enum :status, { inactive: 0, active: 1 }

  # E.164 estricto: +<country code><subscriber number>
  # Requerimos al menos 10 dígitos en total después del '+', y máximo 15.
  PHONE_REGEX = /\A\+[1-9]\d{9,14}\z/

  # Normaliza el número a E.164 usando país por defecto configurable
  before_validation :normalize_phone_number_default!

  validates :phone_number, presence: true,
                           uniqueness: true,
                           format: { with: PHONE_REGEX, message: "debe estar en formato E.164 (ej. +525512345678)" }
  validates :state, presence: true
  validates :user_id, presence: true

  scope :for_state, ->(state_name) { where(state: state_name) }
  scope :owned_by, ->(user) { where(user_id: user.id) }

  private

  def normalize_phone_number_default!
    return if phone_number.blank?
    normalized = PhonyRails.normalize_number(phone_number, country_code: DEFAULT_PHONE_COUNTRY)
    self.phone_number = normalized if normalized.present?
  rescue StandardError
    # Si falla la normalización, la validación mostrará el error de formato
  end
end