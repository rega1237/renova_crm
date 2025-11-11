class AddContactListToCalls < ActiveRecord::Migration[8.0]
  def change
    # Permitir que client_id sea NULL para soportar llamadas a contactos no-clientes o entrantes sin cliente
    change_column_null :calls, :client_id, true

    # Agregar referencia a ContactList opcional
    add_reference :calls, :contact_list, null: true, foreign_key: true

    # Opcional: índice ya se crea por add_reference
    # add_index :calls, :contact_list_id
  end
end