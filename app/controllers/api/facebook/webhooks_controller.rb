module Api
  module Facebook
    class WebhooksController < ApplicationController
      skip_before_action :verify_authenticity_token
      allow_unauthenticated_access

      def verify
        if params["hub.mode"] == "subscribe" && params["hub.verify_token"] == Rails.application.credentials.facebook[:verify_token]
          render plain: params["hub.challenge"], status: :ok
        else
          render plain: "Forbidden", status: :forbidden
        end
      end

      def receive
        ProcessFacebookLeadJob.perform_later(params.to_unsafe_h)
        head :ok
      end
    end
  end
end
