class CreateTextMessages < ActiveRecord::Migration[8.0]
  def change
    create_table :text_messages do |t|
      t.string :twilio_sms_id, null: false
      t.date :sms_date, null: false
      t.time :sms_time, null: false
      t.references :user, null: false, foreign_key: true
      t.string :direction, null: false
      t.references :client, null: true, foreign_key: true
      t.references :contact_list, null: true, foreign_key: true
      t.string :caller_phone, null: false
      t.text :message_body, null: false
      t.string :status
      t.string :to_phone
      t.string :from_phone

      t.timestamps
    end

    add_index :text_messages, :twilio_sms_id, unique: true
    add_index :text_messages, :caller_phone
    add_index :text_messages, :sms_date
    add_index :text_messages, :direction
  end
end
