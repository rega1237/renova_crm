class CreateFacebookIntegrations < ActiveRecord::Migration[8.0]
  def change
    create_table :facebook_integrations do |t|
      t.string :page_id
      t.string :page_name
      t.text :access_token

      t.timestamps
    end
  end
end
