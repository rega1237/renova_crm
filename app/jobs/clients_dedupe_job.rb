# frozen_string_literal: true

class ClientsDedupeJob < ApplicationJob
  queue_as :default

  def perform(current_user_id, dry_run: true, keep_strategy: "oldest")
    Current.user = User.find_by(id: current_user_id)
    service = ClientsDedupeService.new(keep_strategy: keep_strategy)
    result = service.call(dry_run: dry_run)

    Rails.logger.info("[ClientsDedupeJob] Ejecutado por=#{Current.user&.name} dry_run=#{result.dry_run} strategy=#{result.kept_strategy} groups=#{result.groups_considered} dup_groups=#{result.groups_with_duplicates} notes_reassigned=#{result.reassigned_notes} appts_reassigned=#{result.reassigned_appointments} deleted=#{result.duplicates_deleted}")
  ensure
    Current.user = nil
  end
end