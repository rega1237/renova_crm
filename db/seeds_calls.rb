# Script para crear llamadas de prueba
# Ejecutar con: rails runner db/seeds_calls.rb

puts "Creando llamadas de prueba..."

# Obtener algunos clientes y usuarios
clients = Client.limit(5).order(:id)
users = User.limit(3).order(:id)

if clients.empty?
  puts "No hay clientes disponibles. Por favor crea algunos clientes primero."
  exit
end

if users.empty?
  puts "No hay usuarios disponibles. Por favor crea algunos usuarios primero."
  exit
end

# Crear llamadas de prueba
clients.each_with_index do |client, index|
  user = users.sample
  
  # Crear llamadas entrantes y salientes
  3.times do |i|
    call_date = Date.current - i.days
    call_time = Time.current - i.hours
    
    # Llamada entrante
    Call.create!(
      twilio_call_id: "CALL_INCOMING_#{client.id}_#{i}_#{Time.current.to_i}",
      call_date: call_date,
      call_time: call_time,
      duration: rand(30..300),
      user: user,
      client: client,
      direction: "inbound",
      answered: [true, false].sample,
      status: ["completed", "busy", "no-answer", "failed"].sample,
      caller_phone: client.phone || "+1234567890",
      recording_sid: i.even? ? "RE_#{client.id}_#{i}_#{Time.current.to_i}" : nil,
      recording_status: i.even? ? "completed" : nil,
      recording_duration: i.even? ? rand(30..200) : nil,
      contact_list: nil
    )
    
    # Llamada saliente
    Call.create!(
      twilio_call_id: "CALL_OUTGOING_#{client.id}_#{i}_#{Time.current.to_i}",
      call_date: call_date,
      call_time: call_time + 1.hour,
      duration: rand(45..250),
      user: user,
      client: client,
      direction: "outbound",
      answered: true,
      status: ["completed", "busy", "no-answer"].sample,
      caller_phone: nil,
      recording_sid: i.odd? ? "RE_OUT_#{client.id}_#{i}_#{Time.current.to_i}" : nil,
      recording_status: i.odd? ? "completed" : nil,
      recording_duration: i.odd? ? rand(45..180) : nil,
      contact_list: nil
    )
  end
  
  puts "Creadas 6 llamadas para el cliente #{client.name} (#{client.id})"
end

puts "✅ Llamadas de prueba creadas exitosamente!"
puts "Total de llamadas creadas: #{Call.count}"