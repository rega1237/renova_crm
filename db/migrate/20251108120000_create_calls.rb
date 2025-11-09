class CreateCalls < ActiveRecord::Migration[7.1]
  def change
    create_table :calls do |t|
      t.string :twilio_call_id, null: false
      t.date :call_date, null: false
      t.time :call_time, null: false
      t.integer :duration
      t.references :user, null: false, foreign_key: true

      t.timestamps
    end

    add_index :calls, :twilio_call_id, unique: true
    add_index :calls, :call_date
  end
end