class CompanyDropletCreatedJob < ApplicationJob
  queue_as :default

  # payload - Hash received from the webhook controller.
  # Expected structure (example):
  # {
  #   "company_droplet" => {
  #     "fluid_shop" => "example.myshopify.com",
  #     "name" => "Example Shop",
  #     "fluid_company_id" => 123,
  #     "company_droplet_uuid" => "uuid",
  #     "authentication_token" => "token",
  #     "webhook_verification_token" => "verify",
  #     "service_company_id" => "service-id"
  #   }
  # }
  def perform(payload)
    company_attributes = payload.fetch("company_droplet", {})

    company = Company.new(company_attributes.slice(
      "fluid_shop",
      "name",
      "fluid_company_id",
      "company_droplet_uuid",
      "authentication_token",
      "webhook_verification_token",
      "service_company_id"
    ))

    company.active = true

    unless company.save
      Rails.logger.error(
        "[CompanyDropletCreatedJob] Failed to create company: #{company.errors.full_messages.join(', ')}"
      )
    end
  rescue StandardError => e
    Rails.logger.error("[CompanyDropletCreatedJob] Error: #{e.class} - #{e.message}")
    raise
  end
end 