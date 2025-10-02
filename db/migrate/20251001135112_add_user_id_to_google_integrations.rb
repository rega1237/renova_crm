class AddUserIdToGoogleIntegrations < ActiveRecord::Migration[8.0]
  def change
    add_reference :google_integrations, :user, null: false, foreign_key: true
  end
end
