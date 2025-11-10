class AddClientToCalls < ActiveRecord::Migration[8.0]
  def change
    add_reference :calls, :client, null: false, foreign_key: true
  end
end
