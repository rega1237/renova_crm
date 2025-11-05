class ContactList < ApplicationRecord
  belongs_to :state

  DEFAULT_PHONE_COUNTRY = ::DEFAULT_PHONE_COUNTRY

  # Normaliza teléfono similar a Client
  before_validation :normalize_phone_default!

  validates :name, presence: true
  validates :phone, presence: true
  # Validación suave: si comienza con '+', exigir formato E.164
  validates :phone,
            format: {
              with: Number::PHONE_REGEX,
              message: "debe estar en formato E.164 (ej. +13125550123)"
            },
            if: -> { phone.to_s.start_with?("+") }

  # Búsqueda simple por nombre o teléfono
  scope :search, ->(q) {
    return all if q.blank?
    where("LOWER(name) LIKE ? OR phone LIKE ?", "%#{q.to_s.downcase}%", "%#{q}%")
  }

  # Filtro por estado
  scope :by_state, ->(state_id) {
    return all if state_id.blank?
    where(state_id: state_id)
  }

  # Selección automática del número Twilio a usar como caller ID (igual que Client)
  def select_outbound_number_for(user)
    user_numbers = Number.active.owned_by(user)

    contact_state_abbr = state&.abbreviation.to_s.strip
    contact_state_name = state&.name.to_s.strip

    if contact_state_abbr.present? || contact_state_name.present?
      match = user_numbers.where("LOWER(state) = ?", contact_state_abbr.downcase).first if contact_state_abbr.present?
      match ||= user_numbers.where("LOWER(state) = ?", contact_state_name.downcase).first if contact_state_name.present?
      return { number: match, alternatives: [] } if match
    end

    { number: nil, alternatives: user_numbers.order(:state) }
  end

  private

  def normalize_phone_default!
    return if phone.blank?
    str = phone.to_s.strip
    if str.start_with?("+")
      self.phone = str.gsub(/\s+/, "")
      return
    end
    begin
      normalized = PhonyRails.normalize_number(str, country_code: DEFAULT_PHONE_COUNTRY)
      if normalized.present? && normalized.match(Number::PHONE_REGEX)
        self.phone = normalized
      else
        digits = str.gsub(/[^0-9]/, "")
        self.phone = digits if digits.present?
      end
    rescue StandardError
      # Mantener valor original si falla
    end
  end
end