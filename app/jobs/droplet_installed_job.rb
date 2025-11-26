class DropletInstalledJob < WebhookEventJob
  # payload - Hash received from the webhook controller.
  # Expected structure (example):
  # {
  #   "company" => {
  #     "fluid_shop" => "example.myshopify.com",
  #     "name" => "Example Shop",
  #     "fluid_company_id" => 123,
  #     "company_droplet_uuid" => "uuid",
  #     "authentication_token" => "token",
  #     "webhook_verification_token" => "verify",
  #   }
  # }
  def process_webhook
    # Validate required keys in payload
    validate_payload_keys("company")
    company_attributes = get_payload.fetch("company", {})

    company = Company.find_by(fluid_shop: company_attributes["fluid_shop"]) || Company.new

    company.assign_attributes(company_attributes.slice(
      "fluid_shop",
      "name",
      "fluid_company_id",
      "authentication_token",
      "webhook_verification_token",
      "droplet_installation_uuid"
    ))
    company.company_droplet_uuid = company_attributes.fetch("droplet_uuid")
    company.active = true

    unless company.save
      Rails.logger.error(
        "[DropletInstalledJob] Failed to create company: #{company.errors.full_messages.join(', ')}"
      )
      return
    end

    register_active_callbacks(company)
    create_webhooks(company)
  end

  private

  def fluid_client(company)
    @fluid_client ||= FluidClient.new(company.authentication_token)
  end

  def register_active_callbacks(company)
    client = fluid_client(company)
    active_callbacks = ::Callback.active
    installed_callback_ids = []

    active_callbacks.each do |callback|
      begin
        callback_attributes = {
          definition_name: callback.name,
          url: callback.url,
          timeout_in_seconds: callback.timeout_in_seconds,
          active: true,
        }

        response = client.callback_registrations.create(callback_attributes)
        if response && response["callback_registration"]["uuid"]
          installed_callback_ids << response["callback_registration"]["uuid"]
        else
          Rails.logger.warn(
            "[DropletInstalledJob] Callback registered but no UUID returned for: #{callback.name}"
          )
        end
      rescue => e
        Rails.logger.error(
          "[DropletInstalledJob] Failed to register callback #{callback.name}: #{e.message}"
        )
      end
    end

    if installed_callback_ids.any?
      company.update(installed_callback_ids: installed_callback_ids)
    end
  end

  def create_webhooks(company)
    webhooks = Setting.fluid_webhook.values["events"]
    return if webhooks.blank?

    client = fluid_client(company)
    installed_webhook_ids = []

    begin
      webhooks.each do |event|
        resource, event = event.split("_")
        webhook_response = client.webhooks.create(resource: resource, event: event, auth_token: company.authentication_token)

        installed_webhook_ids << webhook_response["id"]
      end
    rescue FluidClient::Error => e
      Rails.logger.error "Failed to create #{resource} #{event} webhook: #{e.message}"
    end

    if installed_webhook_ids.any?
      company.update(installed_webhook_ids: installed_webhook_ids)
    end
  end
end
