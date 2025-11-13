class AddCascadeDeletesToCalls < ActiveRecord::Migration[8.0]
  def change
    # Reemplazar FKs para aplicar borrado en cascada
    # Cliente
    remove_foreign_key :calls, :clients
    add_foreign_key :calls, :clients, on_delete: :cascade

    # ContactList
    remove_foreign_key :calls, :contact_lists
    add_foreign_key :calls, :contact_lists, on_delete: :cascade
  end
end
