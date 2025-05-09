class WebhooksController < ApplicationController
  skip_before_action :verify_authenticity_token
  before_action :authenticate_webhook_token, if: :droplet_installed_or_uninstalled_event?

  def create
    event_type = "#{params[:resource]}.#{params[:event]}"
    version = params[:version]

    payload = params.to_unsafe_h.deep_dup

    if EventHandler.route(event_type, payload, version: version)
      # A 202 Accepted indicates that we have accepted the webhook and queued
      # the appropriate background job for processing.
      head :accepted
    else
      head :no_content
    end
  end

private

  def droplet_installed_or_uninstalled_event?
    params[:resource] == "company_droplet" && %w[installed uninstalled].include?(params[:event])
  end

  def authenticate_webhook_token
    company = find_company
    if company.blank?
      render json: { error: "Company not found" }, status: :not_found
    elsif params[:webhook_verification_token] != company.webhook_verification_token
      render json: { error: "Unauthorized" }, status: :unauthorized
    end
  end

  def find_company
    Company.find_by(company_droplet_uuid: params.dig(:company_droplet, :company_droplet_uuid)) ||
      Company.find_by(fluid_company_id: params.dig(:company_droplet, :fluid_company_id))
  end
end
