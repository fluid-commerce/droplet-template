class DropletUninstalledJob < WebhookEventJob
  queue_as :default

  # Expects event_type, service_id, payload (handled by WebhookEventJob)
  def process_webhook
    validate_payload_keys("company")

    if @company.present?
      @company.update(uninstalled_at: Time.current)
    else
      Rails.logger.warn("[DropletUninstalledJob] Company not found for payload: #{@payload.inspect}")
    end
  end
end
