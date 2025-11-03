class Client < ApplicationRecord
  belongs_to :prospecting_seller, class_name: "Seller", optional: true
  belongs_to :assigned_seller, class_name: "Seller", optional: true
  belongs_to :state, optional: true
  belongs_to :city, optional: true
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
    no_cerro: 7,
    no_aplica_no_interesado: 8
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

  # Normalización de teléfono del cliente a E.164 usando país por defecto.
  # Si el número ya viene en formato internacional (+), se preserva tal cual.
  before_validation :normalize_phone_default!

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

  # Método para determinar la zona horaria del cliente
  def timezone
    case state&.abbreviation # Asumiendo que State tiene una abreviatura (ej. TX, IL)
    when "TX", "IL" # Texas e Illinois
      "America/Chicago" # Zona horaria central
    else
      Rails.application.config.time_zone # Zona horaria por defecto de la aplicación
    end
  end

  # ===========================
  # PRESENCE LOCK (USO ACTIVO)
  # ===========================
  # Timeout en minutos para liberar automáticamente el lock por inactividad
  PRESENCE_LOCK_TIMEOUT_MINUTES = 5

  def presence_lock_expired?
    return true if presence_lock_expires_at.blank?
    Time.current > presence_lock_expires_at
  end

  def presence_locked?
    presence_lock_user_id.present? && !presence_lock_expired?
  end

  def lock_for!(user)
    return false unless user
    # Si está bloqueado por otro y no ha expirado, no permitir
    if presence_locked? && presence_lock_user_id != user.id
      return false
    end

    # Asignar/renovar lock para el usuario actual
    update_columns(
      presence_lock_user_id: user.id,
      presence_lock_expires_at: PRESENCE_LOCK_TIMEOUT_MINUTES.minutes.from_now
    )
    true
  end

  def unlock_if_owner!(user)
    return false unless user
    return false unless presence_lock_user_id == user.id
    update_columns(presence_lock_user_id: nil, presence_lock_expires_at: nil)
    true
  end

  def keepalive_if_owner!(user)
    return false unless user
    return false unless presence_lock_user_id == user.id
    update_columns(presence_lock_expires_at: PRESENCE_LOCK_TIMEOUT_MINUTES.minutes.from_now)
    true
  end

  # Selección automática del número Twilio a usar como caller ID
  # Retorna un hash con:
  #  - :number => Number (cuando hay coincidencia por estado y propiedad)
  #  - :alternatives => [Number] (lista de números activos del usuario para selección manual si no hubo coincidencia)
  def select_outbound_number_for(user)
    user_numbers = Number.active.owned_by(user)

    # Algunos registros de Number guardan el estado como nombre ("Texas") y otros como abreviatura ("TX").
    # Para evitar que falle la auto-asignación por discrepancias, intentamos match por ambos, de forma
    # insensible a mayúsculas/minúsculas y eliminando espacios.
    client_state_abbr = state&.abbreviation.to_s.strip
    client_state_name = state&.name.to_s.strip

    if client_state_abbr.present? || client_state_name.present?
      # Buscar primero por abreviatura, luego por nombre completo
      match = user_numbers.where("LOWER(state) = ?", client_state_abbr.downcase).first if client_state_abbr.present?
      match ||= user_numbers.where("LOWER(state) = ?", client_state_name.downcase).first if client_state_name.present?
      return { number: match, alternatives: [] } if match
    end

    # No hubo match por estado: devolver alternativas para selección manual
    { number: nil, alternatives: user_numbers.order(:state) }
  end

  private

  def update_status_tracking
    attrs = { updated_status_at: Time.current }
    # No sobrescribir updated_by_id con nil si no hay usuario actual
    attrs[:updated_by_id] = Current.user.id if Current.user
    self.update_columns(attrs)
  end

  def normalize_phone_default!
    return if phone.blank?
    str = phone.to_s.strip
    # Si ya viene con '+' (E.164), no renormalizar; solo limpiar espacios
    if str.start_with?("+")
      self.phone = str.gsub(/\s+/, "")
      return
    end
    begin
      normalized = PhonyRails.normalize_number(str, country_code: DEFAULT_PHONE_COUNTRY)
      # Aplicar solo si obtenemos un E.164 válido (con '+') y con longitud correcta
      if normalized.present? && normalized.match(Number::PHONE_REGEX)
        self.phone = normalized
      else
        # Conservar versión solo dígitos para compatibilidad con importaciones y evitar '+' inválidos
        digits = str.gsub(/[^0-9]/, "")
        self.phone = digits if digits.present?
      end
    rescue StandardError
      # Mantener el valor original si falla la normalización
    end
  end

  # Validación suave: si el teléfono comienza con '+', verificar que tenga estructura E.164
  validates :phone,
            format: {
              with: Number::PHONE_REGEX,
              message: "debe estar en formato E.164 (ej. +13125550123)"
            },
            allow_blank: true,
            if: -> { phone.to_s.start_with?("+") }
end
