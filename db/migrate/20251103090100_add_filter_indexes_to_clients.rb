class AddFilterIndexesToClients < ActiveRecord::Migration[8.0]
  def up
    # Habilitar extensión para índices trigram (mejora búsquedas LIKE "%q%")
    enable_extension "pg_trgm" unless extension_enabled?("pg_trgm")

    # Índice simple por zip_code para filtros y ordenaciones
    add_index :clients, :zip_code, name: "index_clients_on_zip_code"

    # Índices parciales (solo ZIP de 5 dígitos) combinados con estado/ciudad, para filtros jerárquicos
    add_index :clients, [ :city_id, :zip_code ],
              where: "zip_code ~ '^[0-9]{5}$'",
              name: "index_clients_on_city_id_and_zip_code_5digits"

    add_index :clients, [ :state_id, :zip_code ],
              where: "zip_code ~ '^[0-9]{5}$'",
              name: "index_clients_on_state_id_and_zip_code_5digits"

    # Índice GIN con trigram para búsquedas por substring en zip_code (LIKE "%q%") del endpoint /api/zipcodes
    execute <<~SQL
      CREATE INDEX IF NOT EXISTS index_clients_on_zip_code_trgm
      ON clients USING gin (zip_code gin_trgm_ops);
    SQL
  end

  def down
    # Eliminar índices creados
    remove_index :clients, name: "index_clients_on_state_id_and_zip_code_5digits" if index_exists?(:clients, name: "index_clients_on_state_id_and_zip_code_5digits")
    remove_index :clients, name: "index_clients_on_city_id_and_zip_code_5digits" if index_exists?(:clients, name: "index_clients_on_city_id_and_zip_code_5digits")
    remove_index :clients, name: "index_clients_on_zip_code" if index_exists?(:clients, name: "index_clients_on_zip_code")
    execute "DROP INDEX IF EXISTS index_clients_on_zip_code_trgm"
    # No deshabilitamos pg_trgm para evitar afectar otros índices potenciales
  end
end
