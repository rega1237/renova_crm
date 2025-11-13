# frozen_string_literal: true

class ClientsDedupeService
  Result = Struct.new(
    :groups_considered,
    :groups_with_duplicates,
    :duplicates_deleted,
    :reassigned_notes,
    :reassigned_appointments,
    :kept_strategy,
    :dry_run,
    keyword_init: true
  )

  def initialize(keep_strategy: ENV.fetch("KEEP_STRATEGY", "oldest"))
    @keep_strategy = keep_strategy.to_s
  end

  def call(dry_run: true)
    result = Result.new(
      groups_considered: 0,
      groups_with_duplicates: 0,
      duplicates_deleted: 0,
      reassigned_notes: 0,
      reassigned_appointments: 0,
      kept_strategy: @keep_strategy,
      dry_run: dry_run
    )

    groups = group_clients_by_phone_key
    result.groups_considered = groups.size

    groups.each do |phone_key, clients|
      next if clients.size <= 1
      result.groups_with_duplicates += 1

      kept, duplicates = select_kept_and_duplicates(clients)

      # Reasignar asociaciones de cada duplicado
      duplicates.each do |dup|
        if dry_run
          # Solo contar lo que se movería, sin modificar la BD
          notes_count = Note.where(client_id: dup.id).count
          appts_count = Appointment.where(client_id: dup.id).count
          result.reassigned_notes += notes_count
          result.reassigned_appointments += appts_count
        else
          # Mover asociaciones y eliminar el duplicado de forma atómica
          ActiveRecord::Base.transaction do
            notes_count = Note.where(client_id: dup.id).update_all(client_id: kept.id)
            appts_count = Appointment.where(client_id: dup.id).update_all(client_id: kept.id)
            result.reassigned_notes += notes_count
            result.reassigned_appointments += appts_count
            dup.destroy!
            result.duplicates_deleted += 1
          end
        end
      end
    end

    result
  end

  private

  def group_clients_by_phone_key
    groups = Hash.new { |h, k| h[k] = [] }
    Client.find_each do |client|
      key = normalize_phone_key(client.phone)
      next if key.blank?
      groups[key] << client
    end
    groups
  end

  def normalize_phone_key(str)
    return "" if str.nil?
    str.to_s.gsub(/[^0-9]/, "")
  end

  def select_kept_and_duplicates(clients)
    case @keep_strategy
    when "latest"
      sorted = clients.sort_by(&:id)
      kept = sorted.last
      [ kept, sorted[0..-2] ]
    else # "oldest" por defecto
      sorted = clients.sort_by(&:id)
      kept = sorted.first
      [ kept, sorted[1..-1] ]
    end
  end
end
