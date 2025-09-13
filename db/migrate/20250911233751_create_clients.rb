class CreateClients < ActiveRecord::Migration[8.0]
  def change
    create_table :clients do |t|
      t.string :name
      t.string :phone
      t.text :address
      t.string :zip_code
      t.string :state
      t.integer :status, default: 0
      t.integer :source
      t.references :seller, null: true, foreign_key: true

      t.timestamps
    end
  end
end
