require "test_helper"

class DropletReinstalledJobTest < ActiveJob::TestCase
  setup do
    @company = companies(:acme)
    @company.update(uninstalled_at: Time.current) # Ensure company is uninstalled
  end

  test "marks company as installed" do
    # Create payload with company identifier
    payload = {
      "company" => {
        "company_droplet_uuid" => @company.company_droplet_uuid,
        "fluid_company_id" => @company.fluid_company_id,
      },
    }

    # Run the job and check that the company is marked as installed
    assert_not_nil @company.reload.uninstalled_at

    DropletReinstalledJob.perform_now(payload)

    assert_nil @company.reload.uninstalled_at
  end

  test "finds company by uuid if provided" do
    # Create payload with only uuid
    payload = {
      "company" => {
        "company_droplet_uuid" => @company.company_droplet_uuid,
      },
    }

    DropletReinstalledJob.perform_now(payload)

    assert_nil @company.reload.uninstalled_at
  end

  test "finds company by fluid_company_id if provided" do
    # Create payload with only fluid_company_id
    payload = {
      "company" => {
        "fluid_company_id" => @company.fluid_company_id,
      },
    }

    DropletReinstalledJob.perform_now(payload)

    assert_nil @company.reload.uninstalled_at
  end

  test "handles missing company gracefully" do
    # Create payload with non-existent identifiers
    payload = {
      "company" => {
        "company_droplet_uuid" => "non-existent-uuid",
        "fluid_company_id" => 9999999,
      },
    }

    # Save the original uninstalled_at time for comparison
    original_uninstalled_at = @company.reload.uninstalled_at

    # Job should run without raising errors
    assert_nothing_raised do
      DropletReinstalledJob.perform_now(payload)
    end

    # Original company should remain unchanged
    assert_equal original_uninstalled_at.to_i, @company.reload.uninstalled_at.to_i
  end

  test "handles empty payload gracefully" do
    # Empty payload
    payload = {}

    # Save the original uninstalled_at time for comparison
    original_uninstalled_at = @company.reload.uninstalled_at

    # Job should run without raising errors
    assert_nothing_raised do
      DropletReinstalledJob.perform_now(payload)
    end

    # Original company should remain unchanged
    assert_equal original_uninstalled_at.to_i, @company.reload.uninstalled_at.to_i
  end
end
