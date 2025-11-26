class AddCallBusyToUsers < ActiveRecord::Migration[7.1]
  def change
    add_column :users, :call_busy, :boolean, default: false, null: false
    add_column :users, :call_busy_since, :datetime
    add_column :users, :current_call_sid, :string
    add_index  :users, :call_busy
    add_index  :users, :current_call_sid
  end
end
