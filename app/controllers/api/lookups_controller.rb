module Api
  class LookupsController < ApplicationController
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
      rec = nil
      if normalized.present?
        rec = klass.where(phone: normalized).first
      end
      if !rec && digits.present?
        rec = klass.where(phone: digits).first
      end
      rec
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
  end
end
