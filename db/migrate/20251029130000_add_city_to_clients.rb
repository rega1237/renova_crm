class AddCityToClients < ActiveRecord::Migration[8.0]
  def change
    add_reference :clients, :city, foreign_key: true, null: true
    add_index :clients, [ :state_id, :city_id ]
  end
end
