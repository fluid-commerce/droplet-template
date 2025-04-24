class SovosController < ApplicationController
  before_action :set_company, only: %i[update_settings]
  skip_before_action :verify_authenticity_token

  def update_settings
    return bad_request_response unless valid_params?

    return not_found_response unless @company.present?

    @company.settings = sanitized_settings

    if @company.save
      redirect_to(
        embed_path(company_droplet_uuid: @company.company_droplet_uuid),
        notice: "Settings updated successfully"
      )
    else
      redirect_to(
        embed_path(company_droplet_uuid: @company.company_droplet_uuid),
        error: "Failed to update settings"
      )
    end
  end

private

  def valid_params?
    required_params = %i[username password hmac_key company_droplet_uuid]
    required_params.all? { |param| params[param].present? }
  end

  def sanitized_settings
    {
      username: params[:username].to_s.strip,
      password: params[:password].to_s.strip,
      hmac_key: params[:hmac_key].to_s.strip,
    }
  end

  def bad_request_response
    render json: { error: "Invalid request parameters" }, status: :bad_request
  end

  def not_found_response
    render json: { error: "Company not Found" }, status: :not_found
  end

  def set_company
    @company = Company.find_by(company_droplet_uuid: params[:company_droplet_uuid])
  end
end
