class CreateInstallers < ActiveRecord::Migration[8.0]
  def change
    create_table :installers do |t|
      t.string :name
      t.string :phone
      t.string :email

      t.timestamps
    end
  end
end
