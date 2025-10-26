class UnauthorizedAccessAttempt < ApplicationRecord
  belongs_to :user, optional: true

  validates :controller_name, :action_name, :path, presence: true
end