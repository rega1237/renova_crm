class Call < ApplicationRecord
  belongs_to :user
  belongs_to :client, optional: true
  belongs_to :contact_list, optional: true

  # Validaciones
  validates :twilio_call_id, presence: true, uniqueness: true
  validates :call_date, presence: true
  validates :call_time, presence: true
  validates :user, presence: true
  validates :duration, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true

  # Direcciones posibles: "outbound-api" (llamadas iniciadas desde el servidor),
  # "outbound-dial" (SDK navegador), "inbound" (llamadas recibidas)
  scope :by_direction, ->(dir) { where(direction: dir) if dir.present? }
  scope :answered, -> { where(answered: true) }
  scope :unanswered, -> { where(answered: false) }
  scope :by_status, ->(st) { where(status: st) if st.present? }

  scope :by_user, ->(user_id) { where(user_id: user_id) if user_id.present? }
  scope :between_dates, ->(start_date, end_date) {
    if start_date.present? && end_date.present?
      where(call_date: start_date..end_date)
    elsif start_date.present?
      where("call_date >= ?", start_date)
    elsif end_date.present?
      where("call_date <= ?", end_date)
    end
  }

  # Fallback para cuando aún no existe el campo answered o no se ha establecido
  def effective_answered?
    return answered unless answered.nil?
    duration.to_i > 0
  end

  validate :client_or_contact_exclusive

  private

  # No permitir que una llamada pertenezca simultáneamente a un cliente y a un contacto.
  # Se permite que ninguno esté presente (p. ej., llamadas entrantes sin asignación).
  def client_or_contact_exclusive
    if client_id.present? && contact_list_id.present?
      errors.add(:base, "La llamada no puede pertenecer a cliente y contacto a la vez")
    end
  end
end