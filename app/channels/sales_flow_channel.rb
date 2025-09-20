class SalesFlowChannel < ApplicationCable::Channel
  def subscribed
    stream_from "sales_flow_channel"
    Rails.logger.info "User subscribed to sales_flow_channel"
  end

  def unsubscribed
    Rails.logger.info "User unsubscribed from sales_flow_channel"
  end
end
