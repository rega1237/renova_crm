class City < ApplicationRecord
  belongs_to :state
  has_many :zipcodes, dependent: :destroy

  validates :name, presence: true, uniqueness: { scope: :state_id, case_sensitive: false }
  validates :state_id, presence: true
  validates :abbreviation, length: { maximum: 10 }, allow_blank: true

  scope :ordered, -> { order(:name) }

  def to_s
    name
  end
end
