class AppointmentsListController < ApplicationController
  def index
    @appointments = filter_appointments

    respond_to do |format|
      format.html
      format.json { render json: appointments_json }
    end
  end

  private

  def filter_appointments
    appointments = Appointment.includes(:client, :seller)

    # Filtrar por fecha o rango de fechas
    if params[:start_date].present? && params[:end_date].present?
      # Rango de fechas
      start_date = Date.parse(params[:start_date])
      end_date = Date.parse(params[:end_date])
      appointments = appointments.where(start_time: start_date.beginning_of_day..end_date.end_of_day)
    elsif params[:start_date].present?
      # Solo fecha de inicio (un día específico)
      start_date = Date.parse(params[:start_date])
      appointments = appointments.where(start_time: start_date.beginning_of_day..start_date.end_of_day)
    end

    # Ordenar por fecha de inicio
    appointments.order(:start_time)
  end

  def appointments_json
    @appointments.map do |appointment|
      {
        id: appointment.id,
        title: appointment.title,
        description: appointment.description,
        start_time: appointment.start_time.strftime("%Y-%m-%d %H:%M"),
        end_time: appointment.end_time.strftime("%Y-%m-%d %H:%M"),
        status: appointment.status,
        client: {
          id: appointment.client.id,
          name: appointment.client.name,
          phone: appointment.client.phone,
          address: appointment.client.address,
          path: helpers.client_path(appointment.client)
        },
        seller: appointment.seller ? {
          id: appointment.seller.id,
          name: appointment.seller.name,
          color: helpers.color_for_seller(appointment.seller)
        } : nil
      }
    end
  end
end
