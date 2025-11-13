module Api
  class LookupsController < ApplicationController
    protect_from_forgery with: :null_session
    # Requiere sesión; estos lookups son internos del CRM
    before_action :resume_session
    before_action :require_current_user!

    def caller
      phone = params[:phone].to_s.strip
      if phone.blank?
        return render json: { name: nil, source: nil }
      end

      normalized = normalize_phone(phone)
      digits = phone.gsub(/[^0-9]/, "")

      client = find_by_phone(Client, normalized, digits)
      if client
        return render json: { name: client.name, source: "client", client_id: client.id }
      end

      contact = find_by_phone(ContactList, normalized, digits)
      if contact
        return render json: { name: contact.name, source: "contact_list", contact_list_id: contact.id }
      end

      render json: { name: nil, source: nil }
    rescue => e
      Rails.logger.warn("[Lookup] caller error: #{e.class} - #{e.message}")
      render json: { name: nil, source: nil }
    end

    private

    def find_by_phone(klass, normalized, digits)
      scope = klass.where.not(phone: [nil, ""]) 
      # 1) Exact matches primero
      if normalized.present?
        rec = scope.where(phone: normalized).first
        return rec if rec
      end
      if digits.present?
        rec = scope.where(phone: digits).first
        return rec if rec
      end

      # 2) Normalizar sólo dígitos y hacer match por sufijo (últimos 10/7)
      return nil if digits.blank?
      last10 = digits[-10..]
      last7  = digits[-7..]

      # Intentar con Postgres: regexp_replace para limpiar no dígitos
      begin
        if last10.present?
          rec = scope.where("regexp_replace(phone, '[^0-9]', '', 'g') LIKE ?", "%#{last10}").first
          return rec if rec
        end
        if last7.present?
          rec = scope.where("regexp_replace(phone, '[^0-9]', '', 'g') LIKE ?", "%#{last7}").first
          return rec if rec
        end
      rescue
        # Fallback para otros adapters (SQLite/MySQL): comparar en Ruby
        cleaned = scope.map { |r| [r, r.phone.to_s.gsub(/[^0-9]/, "")] }
        if last10.present?
          rec = cleaned.find { |(_, digits_db)| digits_db.end_with?(last10) }&.first
          return rec if rec
        end
        if last7.present?
          rec = cleaned.find { |(_, digits_db)| digits_db.end_with?(last7) }&.first
          return rec if rec
        end
      end

      nil
    end

    def normalize_phone(str)
      s = str.to_s.strip
      return s.gsub(/\s+/, "") if s.start_with?("+")
      begin
        normalized = PhonyRails.normalize_number(s, country_code: DEFAULT_PHONE_COUNTRY)
        normalized.presence || s
      rescue
        s
      end
    end

    # Asegura que el endpoint sólo responda si hay usuario en sesión
    def require_current_user!
      unless Current.user
        raw_cookie = cookies[:session_id]
        signed_cookie = nil
        begin
          signed_cookie = cookies.signed[:session_id]
        rescue => e
          Rails.logger.warn("[Lookups] cookies.signed[:session_id] error in require_current_user!: #{e.message}")
        end
        Rails.logger.warn("[Lookups] 401: Current.user=nil raw_cookie=#{raw_cookie.inspect} signed_cookie=#{signed_cookie.inspect} Current.session=#{Current.session&.id}")
        render json: { error: "No autorizado" }, status: :unauthorized
      end
    end
  end
end
