# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.0].define(version: 2025_11_04_000000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
  enable_extension "pg_trgm"

  create_table "appointments", force: :cascade do |t|
    t.bigint "client_id", null: false
    t.bigint "seller_id"
    t.datetime "start_time"
    t.datetime "end_time"
    t.string "title"
    t.text "description"
    t.string "google_event_id"
    t.integer "status", default: 0
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "created_by_id", null: false
    t.string "address"
    t.index ["client_id"], name: "index_appointments_on_client_id"
    t.index ["created_by_id"], name: "index_appointments_on_created_by_id"
    t.index ["google_event_id"], name: "index_appointments_on_google_event_id"
    t.index ["seller_id"], name: "index_appointments_on_seller_id"
  end

  create_table "cities", force: :cascade do |t|
    t.string "name", null: false
    t.string "abbreviation"
    t.bigint "state_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["state_id", "name"], name: "index_cities_on_state_id_and_name", unique: true
    t.index ["state_id"], name: "index_cities_on_state_id"
  end

  create_table "clients", force: :cascade do |t|
    t.string "name"
    t.string "phone"
    t.text "address"
    t.string "zip_code"
    t.integer "status", default: 0
    t.integer "source"
    t.bigint "prospecting_seller_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "email"
    t.bigint "state_id"
    t.datetime "updated_status_at"
    t.integer "updated_by_id"
    t.bigint "assigned_seller_id"
    t.integer "cancellations_count", default: 0, null: false
    t.string "reasons"
    t.bigint "city_id"
    t.integer "presence_lock_user_id"
    t.datetime "presence_lock_expires_at"
    t.index ["assigned_seller_id"], name: "index_clients_on_assigned_seller_id"
    t.index ["city_id", "zip_code"], name: "index_clients_on_city_id_and_zip_code_5digits", where: "((zip_code)::text ~ '^[0-9]{5}$'::text)"
    t.index ["city_id"], name: "index_clients_on_city_id"
    t.index ["presence_lock_expires_at"], name: "index_clients_on_presence_lock_expires_at"
    t.index ["presence_lock_user_id"], name: "index_clients_on_presence_lock_user_id"
    t.index ["prospecting_seller_id"], name: "index_clients_on_prospecting_seller_id"
    t.index ["state_id", "city_id"], name: "index_clients_on_state_id_and_city_id"
    t.index ["state_id", "zip_code"], name: "index_clients_on_state_id_and_zip_code_5digits", where: "((zip_code)::text ~ '^[0-9]{5}$'::text)"
    t.index ["state_id"], name: "index_clients_on_state_id"
    t.index ["updated_by_id"], name: "index_clients_on_updated_by_id"
    t.index ["updated_status_at"], name: "index_clients_on_updated_status_at"
    t.index ["zip_code"], name: "index_clients_on_zip_code"
    t.index ["zip_code"], name: "index_clients_on_zip_code_trgm", opclass: :gin_trgm_ops, using: :gin
  end

  create_table "contact_lists", force: :cascade do |t|
    t.string "name", null: false
    t.string "phone", null: false
    t.bigint "state_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_contact_lists_on_name"
    t.index ["phone"], name: "index_contact_lists_on_phone"
    t.index ["state_id"], name: "index_contact_lists_on_state_id"
  end

  create_table "facebook_integrations", force: :cascade do |t|
    t.string "page_id"
    t.string "page_name"
    t.text "access_token"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "google_integrations", force: :cascade do |t|
    t.string "access_token"
    t.string "refresh_token"
    t.datetime "expires_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["user_id"], name: "index_google_integrations_on_user_id"
  end

  create_table "installers", force: :cascade do |t|
    t.string "name"
    t.string "phone"
    t.string "email"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "notes", force: :cascade do |t|
    t.text "text", null: false
    t.bigint "client_id", null: false
    t.bigint "created_by_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["client_id", "created_at"], name: "index_notes_on_client_id_and_created_at"
    t.index ["client_id"], name: "index_notes_on_client_id"
    t.index ["created_at"], name: "index_notes_on_created_at"
    t.index ["created_by_id"], name: "index_notes_on_created_by_id"
  end

  create_table "numbers", force: :cascade do |t|
    t.string "phone_number", null: false
    t.bigint "user_id", null: false
    t.string "state", null: false
    t.integer "status", default: 1, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["phone_number"], name: "index_numbers_on_phone_number", unique: true
    t.index ["status"], name: "index_numbers_on_status"
    t.index ["user_id", "state"], name: "index_numbers_on_user_id_and_state"
    t.index ["user_id"], name: "index_numbers_on_user_id"
  end

  create_table "sellers", force: :cascade do |t|
    t.string "name"
    t.string "phone"
    t.string "email"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "sessions", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "ip_address"
    t.string "user_agent"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "states", force: :cascade do |t|
    t.string "name", null: false
    t.string "abbreviation", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["abbreviation"], name: "index_states_on_abbreviation"
    t.index ["name"], name: "index_states_on_name"
  end

  create_table "unauthorized_access_attempts", force: :cascade do |t|
    t.bigint "user_id"
    t.string "role_name"
    t.string "controller_name", null: false
    t.string "action_name", null: false
    t.string "path", null: false
    t.string "ip_address"
    t.string "user_agent"
    t.string "message"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["controller_name", "action_name"], name: "idx_on_controller_name_action_name_fc8f7b95ec"
    t.index ["created_at"], name: "index_unauthorized_access_attempts_on_created_at"
    t.index ["user_id"], name: "index_unauthorized_access_attempts_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email", null: false
    t.string "password_digest", null: false
    t.string "name"
    t.integer "rol", default: 0
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "linked_user_id"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["linked_user_id"], name: "index_users_on_linked_user_id"
  end

  create_table "zipcodes", force: :cascade do |t|
    t.string "code", null: false
    t.bigint "city_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["city_id"], name: "index_zipcodes_on_city_id"
    t.index ["code", "city_id"], name: "index_zipcodes_on_code_and_city_id", unique: true
    t.index ["code"], name: "index_zipcodes_on_code"
  end

  create_table "zips", force: :cascade do |t|
    t.string "code", null: false
    t.bigint "city_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["city_id", "code"], name: "index_zips_on_city_id_and_code", unique: true
    t.index ["city_id"], name: "index_zips_on_city_id"
    t.index ["code"], name: "index_zips_on_code"
  end

  add_foreign_key "appointments", "clients"
  add_foreign_key "appointments", "sellers"
  add_foreign_key "appointments", "users", column: "created_by_id"
  add_foreign_key "cities", "states"
  add_foreign_key "clients", "cities"
  add_foreign_key "clients", "sellers", column: "assigned_seller_id"
  add_foreign_key "clients", "sellers", column: "prospecting_seller_id"
  add_foreign_key "clients", "states"
  add_foreign_key "clients", "users", column: "updated_by_id"
  add_foreign_key "contact_lists", "states"
  add_foreign_key "google_integrations", "users"
  add_foreign_key "notes", "clients"
  add_foreign_key "notes", "users", column: "created_by_id"
  add_foreign_key "numbers", "users"
  add_foreign_key "sessions", "users"
  add_foreign_key "unauthorized_access_attempts", "users"
  add_foreign_key "users", "users", column: "linked_user_id"
  add_foreign_key "zipcodes", "cities"
  add_foreign_key "zips", "cities"
end
