class Appointment < ApplicationRecord
  belongs_to :client
  belongs_to :seller, optional: true
  belongs_to :created_by, class_name: "User"

  enum :status, { scheduled: 0, completed: 1, canceled: 2 }

  # Validaciones del lado del servidor (requeridos)
  validates :title, :description, :address, :start_time, presence: true
  validates :created_by, presence: true

  validates :google_event_id, uniqueness: true, allow_nil: true
end
