class AddReasonsToClients < ActiveRecord::Migration[8.0]
  def change
    add_column :clients, :reasons, :string
  end
end
