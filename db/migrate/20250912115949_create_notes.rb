class CreateNotes < ActiveRecord::Migration[8.0]
  def change
    create_table :notes do |t|
      t.text :text, null: false
      t.references :client, null: false, foreign_key: true
      t.references :created_by, null: false, foreign_key: { to_table: :users }

      t.timestamps
    end

    add_index :notes, :created_at
    add_index :notes, [ :client_id, :created_at ]
  end
end
