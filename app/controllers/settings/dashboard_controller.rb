class Settings::DashboardController < ApplicationController
  def index
    @facebook_integration = FacebookIntegration.first
  end
end
