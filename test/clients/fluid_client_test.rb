require "test_helper"

describe FluidClient do
  describe "#payload" do
    it "returns a valid payload" do
      Tasks::Settings.create_defaults
      client = FluidClient.new

      _(client.droplets.payload).must_equal({
        "droplet" => {
          "name" => "Existing Droplet",
          "uuid" => "existing-uuid",
          "active" => true,
          "embed_url" => "https://example.com/existing",
          "settings" => {
            "marketplace_page" => {
              "title" => "Marketplace Title",
              "logo_url" => nil,
              "summary" => nil,
            },
            "details_page" => {
              "title" => "Details Title",
              "logo_url" => nil,
              "summary" => nil,
            },
            "service_operational_countries" => [],
          },
        },
      })
    end
  end

  describe "callbacks" do
    it "returns callbacks resource" do
      Tasks::Settings.create_defaults
      client = FluidClient.new

      _(client.callbacks).must_be_instance_of Fluid::Callbacks::Resource
    end

    it "creates callback with default payload" do
      Tasks::Settings.create_defaults
      client = FluidClient.new
      mock_response = { "callback_registration" => { "id" => "callback-123" } }

      client.stub :post, mock_response do
        result = client.callbacks.create

        _(result).must_equal mock_response
      end
    end

    it "creates callback with custom attributes" do
      Tasks::Settings.create_defaults
      client = FluidClient.new
      mock_response = { "callback_registration" => { "id" => "callback-456" } }
      custom_attributes = {
        definition_name: "custom_callback",
        url: "https://example.com/callback",
        timeout_in_seconds: 30,
        active: false
      }

      client.stub :post, mock_response do
        result = client.callbacks.create(custom_attributes)

        _(result).must_equal mock_response
      end
    end

    it "updates callback" do
      Tasks::Settings.create_defaults
      client = FluidClient.new
      mock_response = { "callback_registration" => { "id" => "callback-789" } }
      callback_id = "callback-123"
      attributes = { timeout_in_seconds: 25 }

      client.stub :put, mock_response do
        result = client.callbacks.update(callback_id, attributes)

        _(result).must_equal mock_response
      end
    end

    it "deletes callback" do
      Tasks::Settings.create_defaults
      client = FluidClient.new
      mock_response = { "deleted" => true }
      callback_id = "callback-123"

      client.stub :delete, mock_response do
        result = client.callbacks.delete(callback_id)

        _(result).must_equal mock_response
      end
    end

    it "gets callbacks" do
      Tasks::Settings.create_defaults
      client = FluidClient.new
      mock_response = { "callbacks" => [] }

      client.stub :get, mock_response do
        result = client.callbacks.get

        _(result).must_equal mock_response
      end
    end

    it "generates correct payload structure" do
      Tasks::Settings.create_defaults
      client = FluidClient.new
      attributes = {
        definition_name: "test_callback",
        url: "https://test.com/callback",
        timeout_in_seconds: 15,
        active: false
      }

      expected_payload = {
        "callback_registration" => {
          "definition_name" => "test_callback",
          "url" => "https://test.com/callback",
          "timeout_in_seconds" => 15,
          "active" => false
        }
      }

      _(client.callbacks.payload(attributes)).must_equal expected_payload
    end

    it "generates payload with defaults when attributes are missing" do
      Tasks::Settings.create_defaults
      client = FluidClient.new
      expected_payload = {
        "callback_registration" => {
          "definition_name" => nil,
          "url" => nil,
          "timeout_in_seconds" => 20,
          "active" => true
        }
      }

      _(client.callbacks.payload).must_equal expected_payload
    end
  end
end
