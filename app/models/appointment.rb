class Appointment < ApplicationRecord
  belongs_to :client
  belongs_to :seller, optional: true

  enum status: { scheduled: 0, completed: 1, canceled: 2 }
end
