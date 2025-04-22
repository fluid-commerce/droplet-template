class WebhooksController < ApplicationController
  skip_before_action :verify_authenticity_token
  before_action :authenticate_webhook_token, if: :droplet_installed_or_uninstalled_event?

  def create
    case [ params[:resource], params[:event] ]
    when %w[company_droplet created]
      handle_company_droplet_created
    when %w[company_droplet uninstalled]
      handle_company_droplet_uninstalled
    when %w[company_droplet installed]
      handle_company_droplet_installed
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

  def handle_company_droplet_created
    company_data = params.require(:company_droplet).permit(
      :fluid_shop, :name, :fluid_company_id, :company_droplet_uuid,
      :authentication_token, :webhook_verification_token, :service_company_id
    )

    company = Company.new(company_data)
    company.active = true

    if company.save
      render json: { success: true, message: "Company created" }, status: :created
    else
      render json: { errors: company.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def handle_company_droplet_uninstalled
    company = find_company

    if company
      company.update(uninstalled_at: Time.current)
      render json: { success: true, message: "Company droplet uninstalled" }
    else
      render json: { error: "Company not found" }, status: :not_found
    end
  end

  def handle_company_droplet_installed
    company = find_company

    if company
      company.update(uninstalled_at: nil)
      render json: { success: true, message: "Company droplet installed" }
    else
      render json: { error: "Company not found" }, status: :not_found
    end
  end

  def find_company
    Company.find_by(company_droplet_uuid: params.dig(:company_droplet, :company_droplet_uuid)) ||
      Company.find_by(fluid_company_id: params.dig(:company_droplet, :fluid_company_id))
  end
end
