class CreateAppointments < ActiveRecord::Migration[8.0]
  def change
    create_table :appointments do |t|
      t.references :client, null: false, foreign_key: true
      t.references :seller, null: true, foreign_key: true
      t.datetime :start_time
      t.datetime :end_time
      t.string :title
      t.text :description
      t.string :google_event_id
      t.integer :status, default: 0

      t.timestamps
    end
    add_index :appointments, :google_event_id
  end
end
