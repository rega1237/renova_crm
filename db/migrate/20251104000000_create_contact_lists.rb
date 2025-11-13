class CreateContactLists < ActiveRecord::Migration[7.1]
  def change
    create_table :contact_lists do |t|
      t.string :name, null: false
      t.string :phone, null: false
      t.references :state, null: false, foreign_key: true

      t.timestamps
    end

    add_index :contact_lists, :name
    add_index :contact_lists, :phone
  end
end
