class CalendarController < ApplicationController
  def index
    @appointments = Appointment.includes(:client, :seller)
  end
end
