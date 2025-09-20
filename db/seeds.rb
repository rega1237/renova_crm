# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Example:
#
#   ["Action", "Comedy", "Drama", "Horror"].each do |genre_name|
#     MovieGenre.find_or_create_by!(name: genre_name)
#   end

User.find_or_create_by!(email: 'admin@renova.com') do |user|
  user.name = 'Admin'
  user.password = 'renova1234' # Cambia esto por una contraseña segura
  user.password_confirmation = 'renova1234' # Y esto también
  user.rol = :admin
 end


puts "Limpiando la base de datos..."
Client.destroy_all
Seller.destroy_all
Installer.destroy_all
State.destroy_all

puts "Creando Vendedores..."
sellers = []
5.times do
  sellers << Seller.create!(
    name: Faker::Name.name,
    phone: Faker::PhoneNumber.cell_phone,
    email: Faker::Internet.unique.email
  )
end
puts "Vendedores creados!"

puts "Creando Instaladores..."
5.times do
  Installer.create!(
    name: Faker::Name.name,
    phone: Faker::PhoneNumber.cell_phone,
    email: Faker::Internet.unique.email
  )
end
puts "Instaladores creados!"

puts "Creando States"

states_ar = [ [ 'Texas', 'TX' ], [ 'Illinois', 'IL' ] ]

states_ar.each do |state|
  State.create!(
    name: state[0],
    abbreviation: state[1]
  )
end

puts "Creando Clientes..."

# Statuses que requieren vendedor asignado
statuses_requiring_assigned_seller = %w[cita_agendada reprogramar vendido mal_credito no_cerro]

users = User.all

50.times do
  client_status = Client.statuses.keys.sample
  client_source = Client.sources.keys.sample

  # Generar una fecha base aleatoria en los últimos 30 días
  base_date = rand(0..30).days.ago + rand(24).hours

  # Determinar prospecting_seller_id (solo si source es prospectacion o referencia)
  prospecting_seller = if %w[prospectacion referencia].include?(client_source)
                        # 90% de las veces asignar un vendedor si es prospectacion o referencia
                        rand(10) < 9 ? sellers.sample : nil
  else
                        nil
  end

  # Determinar assigned_seller_id (solo si status requiere vendedor asignado)
  assigned_seller = if statuses_requiring_assigned_seller.include?(client_status)
                     # 95% de las veces asignar un vendedor si el status lo requiere
                     rand(20) < 19 ? sellers.sample : nil
  else
                     nil
  end

  # Si es lead, updated_status_at es nil, si no, usar la fecha base
  status_updated_at = if client_status == 'lead'
                        nil
  else
                        base_date + rand(1..10).days  # Actualizado algunos días después
  end

  # Crear el cliente
  client = Client.new(
    name: Faker::Name.name,
    email: Faker::Internet.unique.email,
    phone: Faker::PhoneNumber.cell_phone,
    address: Faker::Address.street_address,
    zip_code: Faker::Address.zip_code,
    state_id: State.ordered.sample.id,
    status: client_status,
    source: client_source,
    prospecting_seller: prospecting_seller,
    assigned_seller: assigned_seller,
    updated_status_at: status_updated_at,
    updated_by_id: users.sample.id,  # Asignar un usuario aleatorio
    created_at: base_date
  )

  # Guardar sin validaciones para evitar problemas con fechas del pasado
  client.save!(validate: false)

  # Actualizar manualmente las timestamps para que sean consistentes
  client.update_columns(
    created_at: base_date,
    updated_at: status_updated_at || base_date
  )
end

puts "Clientes creados!"

puts "¡Seed completado!"
