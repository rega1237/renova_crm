class AddStatusTrackingToClients < ActiveRecord::Migration[8.0]
  def change
    add_column :clients, :updated_status_at, :datetime
    add_column :clients, :updated_by_id, :integer

    add_foreign_key :clients, :users, column: :updated_by_id
    add_index :clients, :updated_by_id
    add_index :clients, :updated_status_at
  end
end
