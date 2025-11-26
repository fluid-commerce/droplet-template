class DropletUninstalledJob < WebhookEventJob
  queue_as :default

  def process_webhook
    validate_payload_keys("company")
    company = get_company

    if company.present?
      delete_installed_callbacks(company)
      delete_installed_webhooks(company)

      company.update(uninstalled_at: Time.current)
    else
      Rails.logger.warn("[DropletUninstalledJob] Company not found for payload: #{get_payload.inspect}")
    end
  end

private

  def fluid_client(company)
    @fluid_client ||= FluidClient.new(company.authentication_token)
  end

  def delete_installed_callbacks(company)
    return unless company.installed_callback_ids.present?

    client = fluid_client(company)

    company.installed_callback_ids.each do |callback_id|
      begin
        client.callback_registrations.delete(callback_id)
      rescue => e
        Rails.logger.error("[DropletUninstalledJob] Failed to delete callback #{callback_id}: #{e.message}")
      end
    end

    company.update(installed_callback_ids: [])
  end

  def delete_installed_webhooks(company)
    return unless company.installed_webhook_ids.present?

    client = fluid_client(company)

    company.installed_webhook_ids.each do |webhook_id|
      begin
        client.webhooks.delete(webhook_id)
      rescue => e
        Rails.logger.error("[DropletUninstalledJob] Failed to delete webhook #{webhook_id}: #{e.message}")
      end
    end

    company.update(installed_webhook_ids: [])
  end
end
