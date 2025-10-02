class Client < ApplicationRecord
  belongs_to :prospecting_seller, class_name: "Seller", optional: true
  belongs_to :assigned_seller, class_name: "Seller", optional: true
  belongs_to :state, optional: true
  belongs_to :updated_by, class_name: "User", optional: true
  has_many :notes, dependent: :destroy
  has_many :appointments, dependent: :destroy

  scope :with_recent_notes, -> { includes(:notes).order("notes.created_at DESC") }

  # Scope para filtrar por rango de fechas basado en el status
  scope :by_date_range, ->(date_from, date_to) do
    return all unless date_from.present? || date_to.present?

    query = all

    # Parsear las fechas si son strings
    parsed_date_from = date_from.present? ? Date.parse(date_from.to_s) : nil
    parsed_date_to = date_to.present? ? Date.parse(date_to.to_s) : nil

    # Obtener el valor entero del enum para 'lead'
    lead_status_value = statuses["lead"]

    if parsed_date_from.present? && parsed_date_to.present?
      # Para leads usar created_at, para otros status usar updated_status_at
      query = query.where(
        "(status = ? AND created_at >= ? AND created_at <= ?) OR
         (status != ? AND updated_status_at >= ? AND updated_status_at <= ?)",
        lead_status_value, parsed_date_from.beginning_of_day, parsed_date_to.end_of_day,
        lead_status_value, parsed_date_from.beginning_of_day, parsed_date_to.end_of_day
      )
    elsif parsed_date_from.present?
      query = query.where(
        "(status = ? AND created_at >= ?) OR
         (status != ? AND updated_status_at >= ?)",
        lead_status_value, parsed_date_from.beginning_of_day,
        lead_status_value, parsed_date_from.beginning_of_day
      )
    elsif parsed_date_to.present?
      query = query.where(
        "(status = ? AND created_at <= ?) OR
         (status != ? AND updated_status_at <= ?)",
        lead_status_value, parsed_date_to.end_of_day,
        lead_status_value, parsed_date_to.end_of_day
      )
    end

    query
  rescue ArgumentError
    # Si hay error al parsear las fechas, devolver todos los registros
    all
  end

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
    prospectacion: 3,
    otro: 4
  }

  validates :name, presence: true
  validates :status, presence: true
  validates :source, presence: true

  # Validación: si source es prospectacion o referencia, debe tener prospecting_seller
  validates :prospecting_seller_id, presence: true, if: :requires_prospecting_seller?

  # Callback para actualizar campos de tracking cuando cambie el status
  after_update :update_status_tracking, if: :saved_change_to_status?

  def recent_notes(limit = 5)
    notes.recent.limit(limit)
  end

  def notes_count
    notes.count
  end

  def last_note
    notes.recent.first
  end

  # Método helper para obtener el vendedor principal según el contexto
  def primary_seller
    assigned_seller || prospecting_seller
  end

  # Método helper para saber si requiere vendedor asignado
  def requires_assigned_seller?
    %w[cita_agendada reprogramar vendido mal_credito no_cerro].include?(status)
  end

  # Método helper para saber si es prospectación o referencia
  def requires_prospecting_seller?
    %w[prospectacion referencia].include?(source)
  end

  private

  def update_status_tracking
    self.update_columns(
      updated_status_at: Time.current,
      updated_by_id: Current.user&.id
    )
  end
end
