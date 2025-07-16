# frozen_string_literal: true

require "test_helper"

class DropletServiceTest < ActiveSupport::TestCase
  setup do
    @mock_client = Minitest::Mock.new
    @service = DropletService.new(@mock_client)
  end

  def test_create_when_droplet_creation_is_successful
    droplet_data = {
      "uuid" => "test-uuid",
      "name" => "Test Droplet",
      "active" => true,
      "embed_url" => "https://example.com/embed",
    }

    webhook_data = {
      "resource" => "droplet",
      "url" => "http://localhost:3200/webhook",
      "active" => true,
      "auth_token" => "secret_token",
      "event" => "installed",
      "http_method" => "post",
    }

    droplet_response = { "droplet" => droplet_data }
    webhook_response = { "webhook" => webhook_data }

    droplets_mock = Minitest::Mock.new
    droplets_mock.expect :create, droplet_response

    webhooks_mock = Minitest::Mock.new
    webhooks_mock.expect :create, webhook_response, [
      {
        resource: "droplet",
        url: "http://localhost:3200/webhook",
        active: true,
        auth_token: "secret_token",
        event: "installed",
        http_method: "post",
      },
    ]

    @mock_client.expect :droplets, droplets_mock
    @mock_client.expect :webhooks, webhooks_mock

    result = @service.create

    assert result[:success]
    assert_equal droplet_data, result[:droplet]
    assert_equal webhook_data, result[:webhook]
    assert_equal "test-uuid", settings(:droplet).reload.values["uuid"]
    assert_equal "Test Droplet", settings(:droplet).reload.values["name"]
    assert settings(:droplet).reload.values["active"]
    assert_equal "https://example.com/embed", settings(:droplet).reload.values["embed_url"]
  end

  def test_create_when_fluid_client_raises_an_error
    droplets_mock = Minitest::Mock.new
    droplets_mock.expect :create, nil do
      raise FluidClient::Error, "API Error"
    end
    @mock_client.expect :droplets, droplets_mock

    result = @service.create

    assert_not result[:success]
    assert_equal "API Error", result[:error]
  end

  def test_update_when_droplet_update_is_successful
    webhook_data = {
      "resource" => "droplet",
      "url" => "http://localhost:3200/webhook",
      "active" => true,
      "auth_token" => "secret_token",
      "event" => "installed",
      "http_method" => "post",
    }

    webhook_response = { "webhook" => webhook_data }

    droplets_mock = Minitest::Mock.new
    droplets_mock.expect :update, nil

    webhooks_mock = Minitest::Mock.new
    webhooks_mock.expect :update, webhook_response, [
      {
        resource: "droplet",
        url: "http://localhost:3200/webhook",
        active: true,
        auth_token: "secret_token",
        event: "installed",
        http_method: "post",
      },
    ]

    @mock_client.expect :droplets, droplets_mock
    @mock_client.expect :webhooks, webhooks_mock

    result = @service.update

    assert result[:success]
    assert_equal webhook_data, result[:webhook]
  end

  def test_update_when_fluid_client_raises_an_error
    droplets_mock = Minitest::Mock.new
    droplets_mock.expect :update, nil do
      raise FluidClient::Error, "API Error"
    end
    @mock_client.expect :droplets, droplets_mock

    result = @service.update

    assert_not result[:success]
    assert_equal "API Error", result[:error]
  end

  def test_initialize_uses_provided_client
    custom_client = Minitest::Mock.new
    service = DropletService.new(custom_client)

    assert_equal custom_client.object_id, service.send(:client).object_id
  end

  def test_initialize_creates_new_fluid_client_when_no_client_provided
    service = DropletService.new

    assert_instance_of FluidClient, service.send(:client)
  end
end
