class EmbedController < ApplicationController
  layout "embed_ui"

  def index
    droplet_installation_uuid = params[:dri]

    if droplet_installation_uuid.present?
      @company = Company.find_by(droplet_installation_uuid:)

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
