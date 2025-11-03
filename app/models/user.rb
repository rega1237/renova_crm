class User < ApplicationRecord
  has_secure_password
  has_many :sessions, dependent: :destroy
  has_many :numbers, dependent: :destroy
  has_one :google_integration, dependent: :destroy

  # Permite vincular otra cuenta (por ejemplo, el mismo usuario con rol admin y telemarketing)
  belongs_to :linked_user, class_name: "User", optional: true

  normalizes :email, with: ->(e) { e.strip.downcase }

  # Enum para los roles
  enum :rol, { telemarketing: 0, asistente: 1, admin: 2 }

  # Validaciones
  validates :email, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :name, presence: true
  validates :rol, presence: true

  # IDs de usuario que comparten números: el propio + el vinculado (si existe)
  def shared_user_ids
    linked_user_id.present? ? [ id, linked_user_id ] : [ id ]
  end
  private
end
