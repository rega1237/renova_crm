module Api
  class VoiceCallsController < ApplicationController
    protect_from_forgery with: :null_session

    # Igual que en Api::CallsController: autenticación vía cookie de sesión
    allow_unauthenticated_access only: [:prepare]
    before_action :resume_session

    before_action :require_current_user!
    before_action :require_call_permission!
    before_action :rate_limit!

    # Prepara la llamada devolviendo el número de origen sugerido o alternativas.
    # No inicia la llamada en Twilio; eso lo hará el navegador (WebRTC).
    def prepare
      client = Client.find(params[:client_id])

      unless client.phone.present?
        return render json: { error: "El cliente no tiene teléfono registrado" }, status: :unprocessable_entity
      end

      selection = client.select_outbound_number_for(Current.user)

      from_number_param = params[:from_number]
      from_number_record = nil
      auto_selected = false

      if selection[:number]
        from_number_record = selection[:number]
        auto_selected = true
      elsif from_number_param.present?
        candidate = Number.active.owned_by(Current.user).find_by(phone_number: from_number_param)
        unless candidate
          return render json: {
            error: "El número seleccionado no es válido, no está activo o no te pertenece"
          }, status: :unprocessable_entity
        end
        from_number_record = candidate
      else
        if selection[:alternatives].empty?
          return render json: {
            error: "No tienes números activos disponibles para realizar llamadas"
          }, status: :unprocessable_entity
        end

        return render json: {
          need_selection: true,
          client_state: client.state&.abbreviation,
          alternatives: selection[:alternatives].map { |n|
            {
              phone_number: n.phone_number,
              state: n.state,
              formatted: "#{n.phone_number} (#{n.state})"
            }
          }
        }, status: :ok
      end

      to_number = params[:to_number] || client.phone

      render json: {
        success: true,
        to_number: to_number,
        auto_selected_number: auto_selected ? from_number_record.phone_number : nil,
        selected_number: from_number_record.phone_number,
        client_state: client.state&.abbreviation,
        number_state: from_number_record.state
      }, status: :ok
    end

    private

    def require_current_user!
      unless Current.user
        render json: { error: "No autorizado. Inicia sesión para realizar llamadas." }, status: :unauthorized
      end
    end

    def rate_limit!
      key = "voice:prepare:#{Current.user.id}:#{Time.current.strftime('%Y%m%d%H%M')}"
      count = Rails.cache.read(key).to_i
      if count >= 20
        render json: { error: "Demasiadas solicitudes por minuto. Intenta nuevamente más tarde." }, status: :too_many_requests
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