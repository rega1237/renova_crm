class RenameNombreToNameInUsers < ActiveRecord::Migration[8.0]
  def change
    rename_column :users, :nombre, :name
  end
end
