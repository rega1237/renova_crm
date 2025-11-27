class RemoveCallerPhoneFromTextMessages < ActiveRecord::Migration[8.0]
  def change
    remove_column :text_messages, :caller_phone
  end
end
