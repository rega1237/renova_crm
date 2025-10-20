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

puts "Creando States"

states_ar = [ [ 'Texas', 'TX' ], [ 'Illinois', 'IL' ] ]

states_ar.each do |state|
  State.create!(
    name: state[0],
    abbreviation: state[1]
  )
end

puts "¡Seed completado!"

telemarketing_ar = [
  {
    name: 'Howa',
    email: 'telemarketing1@renova.com',
    password: 'renova1234',
    password_confirmation: 'renova1234'
  },
  {
    name: 'Adriana',
    email: 'telemarketing2@renova.com',
    password: 'renova1234',
    password_confirmation: 'renova1234'
  },
  {
    name: 'Nazareth',
    email: 'telemarketing3@renova.com',
    password: 'renova1234',
    password_confirmation: 'renova1234'
  }
]

telemarketing_ar.each do |telemarketing|
  User.find_or_create_by!(email: telemarketing[:email]) do |user|
    user.name = telemarketing[:name]
    user.password = telemarketing[:password]
    user.password_confirmation = telemarketing[:password_confirmation]
    user.rol = :telemarketing
  end
end
