class AddRecordingFieldsToCalls < ActiveRecord::Migration[8.0]
  def change
    add_column :calls, :recording_sid, :string
    add_column :calls, :recording_status, :string
    add_column :calls, :recording_duration, :integer
    add_index :calls, :recording_sid
  end
end