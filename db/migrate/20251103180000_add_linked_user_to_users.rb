class AddLinkedUserToUsers < ActiveRecord::Migration[8.0]
  def change
    add_reference :users, :linked_user, foreign_key: { to_table: :users }, index: true, null: true
  end
end
