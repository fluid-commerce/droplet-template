class DropletUninstalledJob < WebhookEventJob
  queue_as :default

  def process_webhook
    validate_payload_keys("company")
    company = get_company

    if company.present?
      # Delete installed callbacks using the stored IDs
      delete_installed_callbacks(company)

      # Mark company as uninstalled
      company.update(uninstalled_at: Time.current)

      Rails.logger.info("[DropletUninstalledJob] Successfully uninstalled droplet for company #{company.id}")
    else
      Rails.logger.warn("[DropletUninstalledJob] Company not found for payload: #{get_payload.inspect}")
    end
  end

private

  def delete_installed_callbacks(company)
    return unless company.installed_callback_ids.present?

    client = FluidClient.new
    deleted_count = 0

    company.installed_callback_ids.each do |callback_id|
      begin
        client.callback_registrations.delete(callback_id)
        deleted_count += 1
        Rails.logger.info("[DropletUninstalledJob] Successfully deleted callback with ID: #{callback_id}")
      rescue => e
        Rails.logger.error("[DropletUninstalledJob] Failed to delete callback #{callback_id}: #{e.message}")
      end
    end

    company.update(installed_callback_ids: [])
    Rails.logger.info("[DropletUninstalledJob] Deleted #{deleted_count} callbacks for company #{company.id}")
  end
end