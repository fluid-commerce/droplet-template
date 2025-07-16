class Admin::DropletsController < AdminController
  def create
    result = DropletService.new.create

    if result[:success]
      redirect_to admin_dashboard_index_path, notice: "Droplet created successfully"
    else
      redirect_to admin_dashboard_index_path, alert: "Failed to create droplet: #{result[:error]}"
    end
  end

  def update
    result = DropletService.new.update

    if result[:success]
      redirect_to admin_dashboard_index_path, notice: "Droplet updated successfully"
    else
      redirect_to admin_dashboard_index_path, alert: "Failed to update droplet: #{result[:error]}"
    end
  end
end
