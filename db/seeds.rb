# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Example:
#
#   ["Action", "Comedy", "Drama", "Horror"].each do |genre_name|
#     MovieGenre.find_or_create_by!(name: genre_name)
#   end

# User.find_or_create_by!(email: 'admin@renova.com') do |user|
#   user.name = 'Admin'
#   user.password = 'renova1234' # Cambia esto por una contraseña segura
#   user.password_confirmation = 'renova1234' # Y esto también
#   user.rol = :admin
# end


puts "Limpiando la base de datos..."
Client.destroy_all
Seller.destroy_all
Installer.destroy_all

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

puts "Creando Clientes..."
50.times do
  # Decidimos aleatoriamente si el cliente tendrá un vendedor asignado (aprox. 2/3 de las veces)
  client_seller = rand(3).zero? ? nil : sellers.sample

  Client.create!(
    name: Faker::Name.name,
    email: Faker::Internet.unique.email,
    phone: Faker::PhoneNumber.cell_phone,
    address: Faker::Address.street_address,
    zip_code: Faker::Address.zip_code,
    state_id: State.ordered.sample.id,
    status: Client.statuses.keys.sample, # Elige un estado aleatorio del enum
    source: Client.sources.keys.sample, # Elige una fuente aleatoria del enum
    seller: client_seller # Asigna el vendedor (o nil)
  )
end
puts "Clientes creados!"

puts "¡Seed completado!"
