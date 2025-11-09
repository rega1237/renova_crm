class AddDirectionAndAnsweredToCalls < ActiveRecord::Migration[8.0]
  def change
    add_column :calls, :direction, :string
    add_column :calls, :answered, :boolean
    add_index :calls, :direction
    add_index :calls, :answered
  end
end