require "test_helper"

class CompanyDropletUninstalledJobTest < ActiveJob::TestCase
  setup do
    @company = companies(:acme)
    @company.update(uninstalled_at: nil) # Ensure company is installed
  end
  
  test "marks company as uninstalled" do
    # Create payload with company identifier
    payload = {
      "company_droplet" => {
        "company_droplet_uuid" => @company.company_droplet_uuid,
        "fluid_company_id" => @company.fluid_company_id
      }
    }
    
    # Run the job and check that the company is marked as uninstalled
    assert_nil @company.reload.uninstalled_at
    
    CompanyDropletUninstalledJob.perform_now(payload)
    
    assert_not_nil @company.reload.uninstalled_at
    assert_in_delta Time.current.to_i, @company.uninstalled_at.to_i, 2
  end
  
  test "finds company by uuid if provided" do
    # Create payload with only uuid
    payload = {
      "company_droplet" => {
        "company_droplet_uuid" => @company.company_droplet_uuid
      }
    }
    
    CompanyDropletUninstalledJob.perform_now(payload)
    
    assert_not_nil @company.reload.uninstalled_at
  end
  
  test "finds company by fluid_company_id if provided" do
    # Create payload with only fluid_company_id
    payload = {
      "company_droplet" => {
        "fluid_company_id" => @company.fluid_company_id
      }
    }
    
    CompanyDropletUninstalledJob.perform_now(payload)
    
    assert_not_nil @company.reload.uninstalled_at
  end
  
  test "handles missing company gracefully" do
    # Create payload with non-existent identifiers
    payload = {
      "company_droplet" => {
        "company_droplet_uuid" => "non-existent-uuid",
        "fluid_company_id" => 9999999
      }
    }
    
    # Job should run without raising errors
    assert_nothing_raised do
      CompanyDropletUninstalledJob.perform_now(payload)
    end
    
    # Original company should remain unchanged
    assert_nil @company.reload.uninstalled_at
  end
  
  test "handles empty payload gracefully" do
    # Empty payload
    payload = {}
    
    # Job should run without raising errors
    assert_nothing_raised do
      CompanyDropletUninstalledJob.perform_now(payload)
    end
    
    # Original company should remain unchanged
    assert_nil @company.reload.uninstalled_at
  end
end 