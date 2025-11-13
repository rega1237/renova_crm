# frozen_string_literal: true

namespace :clients do
  desc "Deduplicate clients by phone number (digits-only). KEEP_STRATEGY=oldest|latest DRY_RUN=1"
  task dedupe_by_phone: :environment do
    dry_run = ENV["DRY_RUN"].to_s == "1"
    keep_strategy = ENV.fetch("KEEP_STRATEGY", "oldest")

    service = ClientsDedupeService.new(keep_strategy: keep_strategy)
    result = service.call(dry_run: dry_run)

    puts "Deduplication summary:"
    puts "  dry_run: #{result.dry_run}"
    puts "  strategy: #{result.kept_strategy}"
    puts "  groups_considered: #{result.groups_considered}"
    puts "  groups_with_duplicates: #{result.groups_with_duplicates}"
    puts "  reassigned_notes: #{result.reassigned_notes}"
    puts "  reassigned_appointments: #{result.reassigned_appointments}"
    puts "  duplicates_deleted: #{result.duplicates_deleted}"
  end
end


namespace :clients do
  desc "Deduplicar clientes por teléfono. Mantiene el más reciente por defecto (ID mayor).\n" \
       "Variables: DRY_RUN=1 (no borra, sólo muestra), KEEP_STRATEGY=latest|oldest"
  task dedupe_by_phone: :environment do
    dry_run = ENV["DRY_RUN"].present?
    # Por defecto mantener el más viejo (oldest) para tu caso
    keep_strategy = (ENV["KEEP_STRATEGY"] || "oldest").to_s

    puts "Iniciando deduplicación por teléfono (keep_strategy=#{keep_strategy}, dry_run=#{dry_run})"

    def normalize_phone_key(str)
      s = str.to_s.strip
      return nil if s.blank?
      # Unificar por sólo dígitos para detectar duplicados aunque uno venga en E.164 y otro local
      s.gsub(/[^0-9]/, "")
    end

    grouped = Hash.new { |h, k| h[k] = [] }
    Client.where.not(phone: [ nil, "" ]).find_each(batch_size: 500) do |client|
      key = normalize_phone_key(client.phone)
      next if key.blank?
      grouped[key] << client
    end

    dupe_groups = grouped.select { |_k, arr| arr.size > 1 }
    puts "Grupos con duplicados: #{dupe_groups.size}"

    removed_count = 0
    processed_groups = 0

    dupe_groups.each do |key, arr|
      processed_groups += 1
      sorted = arr.sort_by(&:id)
      keeper = keep_strategy == "oldest" ? sorted.first : sorted.last
      to_delete = sorted - [ keeper ]

      puts "Grupo #{processed_groups}: phone_key=#{key} | keep_id=#{keeper.id} delete_ids=[#{to_delete.map(&:id).join(", ")}]"

      # Reasignar asociaciones para no perder información (Notas, Citas)
      to_delete.each do |dup|
        dup.notes.update_all(client_id: keeper.id)
        dup.appointments.update_all(client_id: keeper.id)
      end

      next if dry_run

      to_delete.each do |dup|
        begin
          dup.destroy!
          removed_count += 1
        rescue => e
          puts "ERROR: No se pudo eliminar cliente ##{dup.id} (tel=#{dup.phone}): #{e.message}"
        end
      end
    end

    puts "Deduplicación finalizada. Grupos procesados: #{processed_groups}. Registros eliminados: #{removed_count}."
    puts "Sugerencia: ejecutar con DRY_RUN=1 primero para revisar, luego ejecutar sin DRY_RUN." if dry_run
  end
end
