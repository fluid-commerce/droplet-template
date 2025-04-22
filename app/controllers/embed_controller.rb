class EmbedController < ApplicationController
  layout "embed_ui"

  def index
    company_droplet_uuid = params[:company_droplet_uuid]

    if company_droplet_uuid.present?
      @company = Company.find_by(company_droplet_uuid:)

      if @company.nil?
        render :not_installed
      elsif @company.uninstalled_at.present?
        render :uninstalled
      else
        render :connected
      end
    else
      render :missing_uuid
    end
  end
end
