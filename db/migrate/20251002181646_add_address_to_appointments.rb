class AddAddressToAppointments < ActiveRecord::Migration[8.0]
  def change
    add_column :appointments, :address, :string
  end
end
