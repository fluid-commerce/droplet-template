class WebhookEventJob < ApplicationJob
  queue_as :webhook_events

  # Retry with exponential backoff
  retry_on StandardError, wait: :exponentially_longer, attempts: 5

  # Ensure idempotency for deserialization errors
  discard_on ActiveJob::DeserializationError

  def perform(payload)
    @event_type = event_type
    @company = find_company
    @payload = payload

    ActiveRecord::Base.transaction do
      process_webhook
    end

    Rails.logger.info("Successfully processed #{self.class.name} for company #{@company.id}, event: #{event_type}")
  rescue StandardError => e
    Rails.logger.error("Error processing #{self.class.name} for company #{@company.id}, event: #{event_type}: #{e.message}")
    raise e
  end

  # To be implemented by subclasses
  def process_webhook
    raise NotImplementedError, "#{self.class.name} must implement #process_webhook"
  end

protected

  def event_type
    EventHandler::EVENT_HANDLERS.key(self.class)
  end

private

  def validate_payload_keys(*required_keys)
    missing_keys = required_keys - @payload.keys
    if missing_keys.any?
      raise ArgumentError, "Missing required payload keys: #{missing_keys.join(', ')}"
    end
  end

  def find_company
    uuid = @payload.dig("company", "company_droplet_uuid")
    fluid_company_id = @payload.dig("company", "fluid_company_id")

    Company.find_by(company_droplet_uuid: uuid) || Company.find_by(fluid_company_id: fluid_company_id)
  end
end
