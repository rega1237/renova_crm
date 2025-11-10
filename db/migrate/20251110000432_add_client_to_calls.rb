class AddClientToCalls < ActiveRecord::Migration[8.0]
  def change
    add_reference :calls, :client, null: true, foreign_key: true
  end
end
