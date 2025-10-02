class CreateGoogleIntegrations < ActiveRecord::Migration[8.0]
  def change
    create_table :google_integrations, if_not_exists: true do |t|
      t.references :user, null: false, foreign_key: true
      t.string :access_token
      t.string :refresh_token
      t.datetime :expires_at

      t.timestamps
    end
  end
end
