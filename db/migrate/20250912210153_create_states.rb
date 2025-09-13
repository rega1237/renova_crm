class CreateStates < ActiveRecord::Migration[8.0]
  def change
    create_table :states do |t|
      t.string :name, null: false
      t.string :abbreviation, null: false
      t.timestamps
    end

    add_index :states, :name
    add_index :states, :abbreviation
  end
end
