class AddAssignedSellerToClients < ActiveRecord::Migration[8.0]
  def change
    # Renombrar seller_id actual a prospecting_seller_id
    rename_column :clients, :seller_id, :prospecting_seller_id

    # Agregar nuevo campo para el vendedor asignado
    add_column :clients, :assigned_seller_id, :bigint
    add_index :clients, :assigned_seller_id

    # Agregar foreign key
    add_foreign_key :clients, :sellers, column: :assigned_seller_id
  end

  def down
    remove_foreign_key :clients, column: :assigned_seller_id
    remove_index :clients, :assigned_seller_id
    remove_column :clients, :assigned_seller_id
    rename_column :clients, :prospecting_seller_id, :seller_id
  end
end
