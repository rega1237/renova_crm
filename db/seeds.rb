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
  user.nombre = 'Admin'
  user.password = 'renova1234' # Cambia esto por una contraseña segura
  user.password_confirmation = 'renova1234' # Y esto también
  user.rol = :admin
end
