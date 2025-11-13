# frozen_string_literal: true

require "active_record"

LOG_PATH = Rails.root.join("tmp", "explain_filters.log")

def print_explain(title, sql)
  lines = []
  lines << "\n=== #{title} ==="
  res = ActiveRecord::Base.connection.execute("EXPLAIN ANALYZE #{sql}")
  res.values.each { |row| lines << row.first }
  File.open(LOG_PATH, "a") { |f| f.puts(lines.join("\n")) }
end

sid = State.limit(1).pluck(:id).first
cid = City.limit(1).pluck(:id).first

print_explain(
  "ZIPs: 5 digits distinct ordered",
  "SELECT DISTINCT zip_code FROM clients WHERE zip_code ~ '^[0-9]{5}$' ORDER BY zip_code"
)

if sid
  print_explain(
    "ZIPs by state_id=#{sid}",
    "SELECT DISTINCT zip_code FROM clients WHERE zip_code ~ '^[0-9]{5}$' AND state_id = #{sid} ORDER BY zip_code"
  )
else
  File.open(LOG_PATH, "a") { |f| f.puts("\n(No state_id available to run state-specific EXPLAIN)") }
end

if cid
  print_explain(
    "ZIPs by city_id=#{cid}",
    "SELECT DISTINCT zip_code FROM clients WHERE zip_code ~ '^[0-9]{5}$' AND city_id = #{cid} ORDER BY zip_code"
  )
else
  File.open(LOG_PATH, "a") { |f| f.puts("\n(No city_id available to run city-specific EXPLAIN)") }
end

print_explain(
  "ZIPs search LIKE '%12%'",
  "SELECT DISTINCT zip_code FROM clients WHERE zip_code ~ '^[0-9]{5}$' AND zip_code LIKE '%12%' ORDER BY zip_code"
)

print_explain(
  "Cities with clients (all)",
  "SELECT DISTINCT cities.id, cities.name, cities.state_id FROM cities INNER JOIN clients ON clients.city_id = cities.id ORDER BY cities.name"
)

if sid
  print_explain(
    "Cities with clients by state_id=#{sid}",
    "SELECT DISTINCT cities.id, cities.name, cities.state_id FROM cities INNER JOIN clients ON clients.city_id = cities.id WHERE cities.state_id = #{sid} ORDER BY cities.name"
  )
end
