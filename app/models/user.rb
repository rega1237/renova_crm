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
  private
end
