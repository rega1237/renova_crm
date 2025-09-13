class Note < ApplicationRecord
  belongs_to :client
  belongs_to :created_by, class_name: "User"

  validates :text, presence: true, length: { minimum: 1, maximum: 1000 }

  scope :recent, -> { order(created_at: :desc) }
  scope :by_user, ->(user) { where(created_by: user) }

  def created_by_name
    created_by&.name || "Usuario desconocido"
  end

  def created_time_ago
    "hace #{time_ago_in_words(created_at)}"
  end

  private

  def time_ago_in_words(time)
    # Implementación básica - Rails tiene ActionView::Helpers::DateHelper.time_ago_in_words
    # pero aquí lo ponemos manual para el modelo
    seconds = Time.current - time
    case seconds
    when 0..59
      "menos de 1 minuto"
    when 60..3599
      "#{(seconds / 60).round} minutos"
    when 3600..86399
      "#{(seconds / 3600).round} horas"
    else
      "#{(seconds / 86400).round} días"
    end
  end
end
