class Call < ApplicationRecord
  belongs_to :user

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
end