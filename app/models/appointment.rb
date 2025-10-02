class Appointment < ApplicationRecord
  belongs_to :client
  belongs_to :seller, optional: true
  belongs_to :created_by, class_name: "User"

  enum status: { scheduled: 0, completed: 1, canceled: 2 }
end
