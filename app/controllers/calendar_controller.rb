class CalendarController < ApplicationController
  def index
    @appointments = Appointment.includes(:client, :seller)
    
    respond_to do |format|
      format.html
      format.json { render json: calendar_events }
    end
  end

  private

  def calendar_events
    @appointments.map do |appt|
      if appt.canceled?
        event_color = '#dc3545' # Rojo para canceladas
      elsif appt.seller.present?
        event_color = helpers.color_for_seller(appt.seller) # Color del vendedor
      else
        event_color = '#808080' # Gris para citas sin vendedor
      end
      
      {
        title: appt.title,
        start: appt.start_time.iso8601,
        end: appt.end_time.iso8601,
        extendedProps: {
          clientPath: helpers.client_path(appt.client)
        },
        backgroundColor: event_color,
        borderColor: event_color
      }
    end
  end
end
