require "test_helper"

class WebhooksControllerTest < ActionDispatch::IntegrationTest
  setup do
    @company = companies(:acme)
  end

  test "should handle company_droplet created event" do
    company_data = {
      fluid_shop: "test-shop",
      name: "Test Company",
      fluid_company_id: 123456,
      company_droplet_uuid: "abc-123-xyz",
      authentication_token: "secret-token-123",
      webhook_verification_token: "verify-token-456",
      service_company_id: "service-123",
    }

    assert_difference("Company.count") do
      post webhook_url, params: {
        resource: "company_droplet",
        event: "created",
        company_droplet: company_data,
      }, as: :json
    end

    assert_response :created

    response_json = JSON.parse(response.body)
    assert_equal true, response_json["success"]
    assert_equal "Company created", response_json["message"]

    company = Company.last
    assert_equal "test-shop", company.fluid_shop
    assert_equal "Test Company", company.name
    assert_equal 123456, company.fluid_company_id
    assert_equal "abc-123-xyz", company.company_droplet_uuid
    assert_equal true, company.active
  end

  test "should handle company_droplet uninstalled event" do
    post webhook_url, params: {
      resource: "company_droplet",
      event: "uninstalled",
      company_droplet: {
        company_droplet_uuid: @company.company_droplet_uuid,
        fluid_company_id: @company.fluid_company_id,
      },
      webhook_verification_token: @company.webhook_verification_token
    }, as: :json

    assert_response :success

    response_json = JSON.parse(response.body)
    assert_equal true, response_json["success"]
    assert_equal "Company droplet uninstalled", response_json["message"]

    @company.reload
    assert_not_nil @company.uninstalled_at
  end

  test "should handle company_droplet installed event" do
    # First mark the company as uninstalled
    @company.update(uninstalled_at: Time.current)

    post webhook_url, params: {
      resource: "company_droplet",
      event: "installed",
      company_droplet: {
        company_droplet_uuid: @company.company_droplet_uuid,
        fluid_company_id: @company.fluid_company_id,
      },
      webhook_verification_token: @company.webhook_verification_token
    }, as: :json

    assert_response :success

    response_json = JSON.parse(response.body)
    assert_equal true, response_json["success"]
    assert_equal "Company droplet installed", response_json["message"]

    @company.reload
    assert_nil @company.uninstalled_at
  end

  test "should return 404 when company not found" do
    post webhook_url, params: {
      resource: "company_droplet",
      event: "uninstalled",
      company_droplet: {
        company_droplet_uuid: "non-existent-uuid",
        fluid_company_id: 999999,
      },
    }, as: :json

    assert_response :not_found

    response_json = JSON.parse(response.body)
    assert_equal "Company not found", response_json["error"]
  end

  test "should handle unknown event types with no content" do
    post webhook_url, params: {
      resource: "unknown_resource",
      event: "unknown_event",
    }, as: :json

    assert_response :no_content
  end

  test "should verify event when webhook verification token is valid" do
    post webhook_url, params: {
      resource: "company_droplet",
      event: "uninstalled",
      company_droplet: {
        company_droplet_uuid: @company.company_droplet_uuid,
        fluid_company_id: @company.fluid_company_id,
      },
      webhook_verification_token: @company.webhook_verification_token
    }, as: :json

    assert_response :success
  end

  test "should reject event when webhook verification token is invalid" do
    post webhook_url, params: {
      resource: "company_droplet",
      event: "uninstalled",
      company_droplet: {
        company_droplet_uuid: @company.company_droplet_uuid,
        fluid_company_id: @company.fluid_company_id,
      },
      webhook_verification_token: "invalid-token"
    }, as: :json

    assert_response :unauthorized
  end

  test "should bypass verification for company_droplet created event" do
    company_data = {
      fluid_shop: "new-shop",
      name: "New Company",
      fluid_company_id: 999999,
      company_droplet_uuid: "new-uuid-123",
      authentication_token: "new-secret-token",
      webhook_verification_token: "new-verify-token",
      service_company_id: "new-service-123",
    }

    # No webhook_verification_token provided, but should still succeed
    assert_difference("Company.count") do
      post webhook_url, params: {
        resource: "company_droplet",
        event: "created",
        company_droplet: company_data,
      }, as: :json
    end

    assert_response :created
  end
end
