class ProcessFacebookLeadJob < ApplicationJob
  queue_as :default

  def perform(webhook_payload)
    entry = webhook_payload.dig("entry", 0, "changes", 0, "value")
    lead_id = entry&.dig("leadgen_id")
    return unless lead_id

    puts "Procesando el Lead ID: #{lead_id}"
    Facebook::LeadProcessor.new(lead_id: lead_id).process
  end
end
