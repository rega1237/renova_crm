class AppointmentsController < ApplicationController
  before_action :set_client

  def new
    @appointment = @client.appointments.new
  end

  def create
    @appointment = @client.appointments.new(appointment_params)
    @appointment.created_by = Current.user

    if @appointment.save
      CreateGoogleEventJob.perform_later(@appointment)
      # Respond with Turbo Stream to close the form and show a success message
      render turbo_stream: turbo_stream.update("appointment-form-container", "<p>Cita creada exitosamente. Se está procesando en Google Calendar.</p>")
    else
      # Respond with Turbo Stream to re-render the form with errors
      render :new, status: :unprocessable_entity
    end
  end

  private

  def set_client
    @client = Client.find(params[:client_id])
  end

  def appointment_params
    params.require(:appointment).permit(:title, :description, :start_time, :end_time, :seller_id)
  end
end
