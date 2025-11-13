class CreateNumbers < ActiveRecord::Migration[7.1]
  def change
    create_table :numbers do |t|
      t.string :phone_number, null: false
      t.references :user, null: false, foreign_key: true
      t.string :state, null: false
      t.integer :status, null: false, default: 1

      t.timestamps
    end

    add_index :numbers, :phone_number, unique: true
    add_index :numbers, [ :user_id, :state ]
    add_index :numbers, :status
  end
end
