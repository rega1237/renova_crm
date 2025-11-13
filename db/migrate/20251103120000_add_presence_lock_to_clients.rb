class AddPresenceLockToClients < ActiveRecord::Migration[7.0]
  def change
    add_column :clients, :presence_lock_user_id, :integer
    add_column :clients, :presence_lock_expires_at, :datetime
    add_index :clients, :presence_lock_user_id
    add_index :clients, :presence_lock_expires_at
  end
end
