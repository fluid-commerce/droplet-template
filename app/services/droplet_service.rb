# frozen_string_literal: true

class DropletService
  def initialize(client = nil)
    @client = client || FluidClient.new
  end

  def create
    droplet_data = create_droplet
    webhook_data = create_webhook

    { success: true, droplet: droplet_data, webhook: webhook_data }
  rescue FluidClient::Error => e
    { success: false, error: e.message }
  end

  def update
    update_droplet
    webhook_data = update_webhook

    { success: true, webhook: webhook_data }
  rescue FluidClient::Error => e
    { success: false, error: e.message }
  end

private

  attr_reader :client

  def create_droplet
    response = @client.droplets.create
    update_droplet_setting(response["droplet"])
    response["droplet"]
  end

  def create_webhook
    response = @client.webhooks.create(webhook_attributes)
    update_webhook_setting(response["webhook"])
    response["webhook"]
  end

  def update_droplet
    @client.droplets.update
  end

  def update_webhook
    response = @client.webhooks.update(webhook_attributes)
    response["webhook"]
  end

  def update_droplet_setting(droplet_data)
    setting = Setting.droplet
    setting.values = droplet_data.slice("uuid", "name", "active", "embed_url")
    setting.save!
  end

  def update_webhook_setting(webhook_data)
    webhook_setting = Setting.fluid_webhook
    webhook_setting.values["webhook_id"] = webhook_data["id"].to_s
    webhook_setting.save!
  end

  def webhook_attributes
    webhook_setting = Setting.fluid_webhook
    {
      resource: "droplet",
      url: webhook_setting.url,
      active: true,
      auth_token: webhook_setting.auth_token,
      event: "installed",
      http_method: webhook_setting.http_method.downcase,
    }
  end
end
