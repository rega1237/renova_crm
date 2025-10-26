class CreateUnauthorizedAccessAttempts < ActiveRecord::Migration[7.1]
  def change
    create_table :unauthorized_access_attempts do |t|
      t.references :user, foreign_key: true
      t.string :role_name
      t.string :controller_name, null: false
      t.string :action_name, null: false
      t.string :path, null: false
      t.string :ip_address
      t.string :user_agent
      t.string :message

      t.timestamps
    end

    add_index :unauthorized_access_attempts, [ :controller_name, :action_name ]
    add_index :unauthorized_access_attempts, :created_at
  end
end
