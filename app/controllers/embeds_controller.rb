class EmbedsController < ApplicationController
  def index
    @company = Company.find_by(company_droplet_uuid: params[:company_droplet_uuid])
    if @company.nil?
      render :initialize
    else
      render :index
    end
  end
end
