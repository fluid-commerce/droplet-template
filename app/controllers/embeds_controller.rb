class EmbedsController < ApplicationController
  def index
    # hard-coded for now
    params[:company_droplet_uuid] = "cdr_znmpvbr5x7ndkotlhpvnyt5b5qfzvxzf"
    @company = Company.find_by(company_droplet_uuid: params[:company_droplet_uuid])
    if @company.present? && @company.settings.present?
      render :index
    else
      render :initialize
    end
  end

  def update
    @company = Company.find_by(company_droplet_uuid: params[:company_droplet_uuid])

    if @company.present?
      @company.settings = {
        username: params[:username],
        password: params[:password],
        hmac_key: params[:hmac_key],
      }

      if @company.save
        redirect_to embed_path(company_droplet_uuid: @company.company_droplet_uuid),
notice: "Settings updated successfully"
      else
        render :initialize
      end
    else
      render :initialize
    end
  end
end
