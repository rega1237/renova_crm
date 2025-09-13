class Client < ApplicationRecord
  belongs_to :seller, optional: true
  belongs_to :state, optional: true
  has_many :notes, dependent: :destroy

  scope :with_recent_notes, -> { includes(:notes).order("notes.created_at DESC") }

  enum :status, {
    lead: 0,
    no_contesto: 1,
    seguimiento: 2,
    cita_agendada: 3,
    reprogramar: 4,
    vendido: 5,
    mal_credito: 6,
    no_cerro: 7
  }

  enum :source, {
    base_de_datos: 0,
    meta: 1,
    referencia: 2,
    propectacion: 3,
    otro: 4
  }

  validates :name, presence: true
  validates :status, presence: true
  validates :source, presence: true

  def recent_notes(limit = 5)
    notes.recent.limit(limit)
  end

  def notes_count
    notes.count
  end

  def last_note
    notes.recent.first
  end
end
