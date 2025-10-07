class CalendarChannel < ApplicationCable::Channel
  def subscribed
    stream_from "calendar_updates"
  end

  def unsubscribed
    # Any cleanup needed when channel is unsubscribed
  end
end
