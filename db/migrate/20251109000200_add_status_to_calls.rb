class AddStatusToCalls < ActiveRecord::Migration[8.0]
  def change
    add_column :calls, :status, :string
    add_index :calls, :status
  end
end