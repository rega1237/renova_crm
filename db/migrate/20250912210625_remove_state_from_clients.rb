class RemoveStateFromClients < ActiveRecord::Migration[8.0]
  def change
    remove_column :clients, :state, :string
  end
end
