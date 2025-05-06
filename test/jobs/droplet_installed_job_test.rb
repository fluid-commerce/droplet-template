require "test_helper"

class DropletInstalledJobTest < ActiveJob::TestCase
  test "creates a company from payload" do
    # Create test data
    company_data = {
      "fluid_shop" => "test-shop-123",
      "name" => "Test Shop",
      "fluid_company_id" => 12345,
      "company_droplet_uuid" => "test-uuid-123",
      "authentication_token" => "test-auth-token",
      "webhook_verification_token" => "test-verify-token",
    }

    payload = { "company" => company_data }

    # Test that the job creates a company
    assert_difference "Company.count", 1 do
      DropletInstalledJob.perform_now(payload)
    end

    # Find the created company
    company = Company.last

    # Verify company attributes
    assert_equal "test-shop-123", company.fluid_shop
    assert_equal "Test Shop", company.name
    assert_equal 12345, company.fluid_company_id
    assert_equal "test-uuid-123", company.company_droplet_uuid
    assert_equal "test-auth-token", company.authentication_token
    assert_equal "test-verify-token", company.webhook_verification_token
    assert company.active?
  end

  test "handles missing company droplet data" do
    # Empty payload
    payload = {}

    # Job should run without creating a company or raising errors
    assert_no_difference "Company.count" do
      assert_nothing_raised do
        DropletInstalledJob.perform_now(payload)
      end
    end
  end

  test "handles invalid company data" do
    # Create invalid data (missing required fields)
    payload = {
      "company" => {
        "name" => "Invalid Company",
        # Missing required fields
      },
    }

    # Job should run without creating a company or raising errors
    assert_no_difference "Company.count" do
      assert_nothing_raised do
        DropletInstalledJob.perform_now(payload)
      end
    end
  end
end
