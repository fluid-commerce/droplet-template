class AddInstalledWebhookIdsToCompany < ActiveRecord::Migration[8.0]
  def change
    add_column :companies, :installed_webhook_ids, :jsonb, default: []
  end
end
