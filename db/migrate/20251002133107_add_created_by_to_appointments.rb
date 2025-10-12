class AddCreatedByToAppointments < ActiveRecord::Migration[8.0]
  def change
    add_reference :appointments, :created_by, null: false, foreign_key: { to_table: :users }
  end
end
