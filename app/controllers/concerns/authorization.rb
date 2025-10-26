module Authorization
  extend ActiveSupport::Concern

  private
    def forbid_telemarketing!(message: "")
      if Current.user&.telemarketing?
        # Registro sin mostrar alerta al usuario (UX sin fricción para roles válidos)
        log_unauthorized_attempt(message: message.presence || "Telemarketing bloqueado en Dashboard")
        redirect_to clients_path
        false
      else
        true
      end
    end

    def require_admin!(message: "Acceso no autorizado")
      unless Current.user&.admin?
        log_unauthorized_attempt(message: message)
        redirect_to root_path, alert: message
        false
      else
        true
      end
    end

    def log_unauthorized_attempt(message: "Acceso no autorizado")
      begin
        UnauthorizedAccessAttempt.create!(
          user: Current.user,
          role_name: Current.user&.rol,
          controller_name: self.class.name,
          action_name: action_name,
          path: request.fullpath,
          ip_address: request.remote_ip,
          user_agent: request.user_agent,
          message: message
        )
      rescue => e
        Rails.logger.warn("UnauthorizedAccessAttempt log failed: #{e.class} - #{e.message}")
      end
    end
end
