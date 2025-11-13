class CreateZipcodes < ActiveRecord::Migration[8.0]
  def change
    create_table :zipcodes do |t|
      t.string :code, null: false
      t.references :city, null: false, foreign_key: true

      t.timestamps
    end

    add_index :zipcodes, :code
    add_index :zipcodes, [ :code, :city_id ], unique: true
  end
end
