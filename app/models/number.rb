# frozen_string_literal: true

class Number < ApplicationRecord
  belongs_to :user

  enum :status, { inactive: 0, active: 1 }

  # E.164 estricto: +<country code><subscriber number> (hasta 15 dígitos)
  PHONE_REGEX = /\A\+[1-9]\d{1,14}\z/

  validates :phone_number, presence: true,
                           uniqueness: true,
                           format: { with: PHONE_REGEX, message: "debe estar en formato E.164 (ej. +525512345678)" }
  validates :state, presence: true
  validates :user_id, presence: true

  scope :for_state, ->(state_name) { where(state: state_name) }
  scope :owned_by, ->(user) { where(user_id: user.id) }
end