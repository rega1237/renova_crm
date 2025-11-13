# frozen_string_literal: true

class ProgressChannel < ApplicationCable::Channel
  def subscribed
    pid = params[:pid].to_s
    reject && return if pid.blank?
    stream_from "progress:#{pid}"
  end

  def unsubscribed
    # Any cleanup needed when channel is unsubscribed
  end
end
