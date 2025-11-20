# Verificar llamadas creadas
puts "=== VERIFICACIÓN DE LLAMADAS ==="
puts "Total de llamadas en la base de datos: #{Call.count}"
puts ""

# Mostrar algunas llamadas con detalles
puts "=== MUESTRA DE LLAMADAS ==="
Call.includes(:client, :user).limit(10).each do |call|
  puts "ID: #{call.id} | Cliente: #{call.client&.name || 'N/A'} (#{call.client_id}) | Usuario: #{call.user&.name || 'N/A'} | Fecha: #{call.call_date} | Dirección: #{call.direction} | Estado: #{call.status}"
end

puts ""
puts "=== LLAMADAS POR CLIENTE ==="
Client.includes(:calls).limit(5).each do |client|
  puts "#{client.name} (#{client.id}): #{client.calls.count} llamadas"
end

puts ""
puts "=== LLAMADAS CON GRABACIÓN ==="
calls_with_recording = Call.where.not(recording_sid: nil).count
puts "Llamadas con grabación: #{calls_with_recording}"

puts ""
puts "✅ Verificación completa!"