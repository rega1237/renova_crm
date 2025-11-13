class AddCallerPhoneToCalls < ActiveRecord::Migration[8.0]
  def change
    add_column :calls, :caller_phone, :string
  end
end
