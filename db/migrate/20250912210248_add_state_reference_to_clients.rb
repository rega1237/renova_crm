class AddStateReferenceToClients < ActiveRecord::Migration[8.0]
  def change
    add_reference :clients, :state, null: true, foreign_key: true
  end
end
