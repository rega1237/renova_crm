module Api
  class CallsController < ApplicationController
    protect_from_forgery with: :null_session

    # Evitar el redirect HTML del concern Authentication y manejar auth como JSON
    allow_unauthenticated_access only: [:create]
    # Asegurar que Current.user se setee desde cookie de sesión si existe
    before_action :resume_session

    before_action :require_current_user!
    before_action :require_call_permission!
    before_action :rate_limit!

    def create
      client = Client.find(params[:client_id])
      selection = client.select_outbound_number_for(Current.user)

      from_number_param = params[:from_number]
      from_number_record = nil

      if selection[:number]
        from_number_record = selection[:number]
      elsif from_number_param.present?
        candidate = Number.active.owned_by(Current.user).find_by(phone_number: from_number_param)
        from_number_record = candidate
      else
        # No match by state and no manual selection provided
        return render json: {
          need_selection: true,
          alternatives: selection[:alternatives].map { |n| { phone_number: n.phone_number, state: n.state } }
        }, status: :ok
      end

      unless from_number_record
        return render json: { error: "Número de origen no válido o no disponible" }, status: :unprocessable_entity
      end

      to_number = params[:to_number] || client.phone
      if to_number.blank?
        return render json: { error: "El cliente no tiene teléfono registrado" }, status: :unprocessable_entity
      end

      result = CallService.new(client: client, to_number: to_number, from_number: from_number_record.phone_number, user: Current.user).call!

      if result.success
        render json: { success: true, sid: result.sid, status: result.status }
      else
        render json: { error: result.error }, status: :bad_gateway
      end
    end

    private

    def require_current_user!
      unless Current.user
        # Responder siempre en JSON para que el frontend pueda manejar el 401 sin romper
        render json: { error: "No autorizado. Inicia sesión para realizar llamadas." }, status: :unauthorized
      end
    end

    def rate_limit!
      # Simple rate limiting: max 10 requests per minute per user
      key = "calls:rate:#{Current.user.id}:#{Time.current.strftime('%Y%m%d%H%M')}"
      count = Rails.cache.read(key).to_i
      if count >= 10
        render json: { error: "Límite de llamadas por minuto alcanzado. Intenta nuevamente más tarde." }, status: :too_many_requests
      else
        Rails.cache.write(key, count + 1, expires_in: 1.minute)
      end
    end

    def require_call_permission!
      user = Current.user
      allowed_roles = ["telemarketing", "admin"]
      unless user && allowed_roles.include?(user.rol.to_s)
        render json: { error: "No autorizado para realizar llamadas" }, status: :forbidden
      end
    end
  end
end