class AppointmentsController < ApplicationController
  before_action :set_client



  def create
    @appointment = @client.appointments.new(appointment_params)
    @appointment.created_by = Current.user
    # Asignar end_time automáticamente 1 hora después del start_time
    @appointment.end_time = @appointment.start_time + 1.hour if @appointment.start_time

    if @appointment.save
      CreateGoogleEventJob.perform_later(@appointment)
      flash.now[:notice] = "Cita agendada exitosamente. Se está sincronizando con Google Calendar."

      streams = [
        turbo_stream.update("appointment-form-container", ""),
        turbo_stream.prepend("notifications-container", partial: "shared/flash_message", locals: { type: "notice", message: flash.now[:notice] })
      ]

      # Si el cliente no tiene vendedor y se asignó uno en la cita, actualizar al cliente.
      if @client.assigned_seller.nil? && @appointment.seller.present?
        @client.update(assigned_seller: @appointment.seller)
        # Añadir un stream para actualizar la sección del vendedor asignado en la vista del cliente.
        streams << turbo_stream.replace("assigned-seller-section", partial: "clients/assigned_seller_section", locals: { client: @client })
      end

      render turbo_stream: streams
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

  def set_client
    @client = Client.find(params[:client_id])
  end

  def appointment_params
    params.require(:appointment).permit(:title, :description, :start_time, :seller_id)
  end
end
