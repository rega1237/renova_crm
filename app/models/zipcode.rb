class Zipcode < ApplicationRecord
  belongs_to :city

  validates :code, presence: true, uniqueness: { scope: :city_id, case_sensitive: false }
  validates :city_id, presence: true
  validates :code, length: { minimum: 3, maximum: 10 }
  validates :code, format: { with: /\A[0-9A-Za-z\-\s]+\z/, message: "solo puede contener números, letras, guiones y espacios" }

  scope :ordered, -> { order(:code) }
  scope :by_city, ->(city) { where(city: city) }

  def to_s
    code
  end

  def full_description
    "#{code} - #{city.name}, #{city.state.abbreviation}"
  end
end