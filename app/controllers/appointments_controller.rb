class AppointmentsController < ApplicationController
  before_action :set_client

  def create
    @appointment = @client.appointments.new(appointment_params)
    @appointment.created_by = Current.user
    @appointment.end_time = @appointment.start_time + 1.hour if @appointment.start_time

    if @appointment.save
      CreateGoogleEventJob.perform_later(@appointment)
      flash.now[:notice] = "Cita agendada exitosamente. Se está sincronizando con Google Calendar."

      # --- Lógica de actualización de Cliente y Broadcast ---
      update_client_and_broadcast

    else
      # Re-render the form with errors
      render turbo_stream: turbo_stream.update(
        "appointment-form-container",
        partial: "appointments/form",
        locals: { client: @client, appointment: @appointment }
      ), status: :unprocessable_entity
    end
  end

  private

  def update_client_and_broadcast
    streams = [
      turbo_stream.update("appointment-form-container", ""),
      turbo_stream.prepend("notifications-container", partial: "shared/flash_message", locals: { type: "notice", message: flash.now[:notice] })
    ]

    should_update_seller = @client.assigned_seller.nil? && @appointment.seller.present?
    should_update_status = [ "lead", "no_contesto", "seguimiento" ].include?(@client.status)

    if should_update_seller || should_update_status
      old_status = @client.status
      update_params = {}
      update_params[:assigned_seller] = @appointment.seller if should_update_seller
      update_params[:status] = "cita_agendada" if should_update_status

      if @client.update(update_params)
        streams << turbo_stream.replace("assigned-seller-section", partial: "clients/assigned_seller_section", locals: { client: @client }) if should_update_seller

        if should_update_status
          client_html = ApplicationController.render(partial: "sales_flow/client_card", locals: { client: @client })
          ActionCable.server.broadcast(
            "sales_flow_channel",
            {
              action: "client_moved",
              client_id: @client.id,
              client_name: @client.name,
              updated_by_name: Current.user&.name || "Sistema",
              old_status: old_status,
              new_status: "cita_agendada",
              updated_at: @client.updated_status_at,
              client_html: client_html
            }
          )
        end
      end
    end

    render turbo_stream: streams
  end

  private

  def set_client
    @client = Client.find(params[:client_id])
  end

  def appointment_params
    params.require(:appointment).permit(:title, :description, :start_time, :seller_id)
  end
end
