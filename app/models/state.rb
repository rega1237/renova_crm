class State < ApplicationRecord
  has_many :clients, dependent: :nullify

  validates :name, presence: true, uniqueness: { case_sensitive: false }
  validates :abbreviation, presence: true, uniqueness: { case_sensitive: false }

  scope :ordered, -> { order(:name) }

  def to_s
    name
  end

  def display_name_with_abbreviation
    "#{name} (#{abbreviation})"
  end
end
