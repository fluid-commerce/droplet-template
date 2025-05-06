require "test_helper"

class EventHandlerTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  # Define test handler classes as constants
  class TestHandlerJob < ApplicationJob
    def perform(payload)
      # Test implementation
    end
  end

  class V1HandlerJob < ApplicationJob
  end

  class V2HandlerJob < ApplicationJob
  end

  class FallbackHandlerJob < ApplicationJob
  end

  class VersionedEventHandler < ApplicationJob
  end

  class ErrorHandlerJob < ApplicationJob
    def self.perform_later(*)
      raise "Test exception"
    end
  end

  class MultiArgHandlerJob < ApplicationJob
  end

  class CustomRuntimeHandlerJob < ApplicationJob
  end

  setup do
    # Clear the handlers before each test to start with a clean slate
    EventHandler::EVENT_HANDLERS.clear
  end

  teardown do
    # Restore default handlers after each test
    EventHandler::EVENT_HANDLERS.clear
    EventHandler.register_handler("company_droplet.created", DropletInstalledJob)
    EventHandler.register_handler("company_droplet.uninstalled", DropletUninstalledJob)
    EventHandler.register_handler("company_droplet.installed", DropletInstalledJob)
  end

  test "registers and routes to a handler" do
    # Register the handler
    EventHandler.register_handler("test.event", TestHandlerJob)

    # Check that it was registered
    assert_equal TestHandlerJob, EventHandler::EVENT_HANDLERS["test.event"]

    # Test routing with payload
    payload = { "test" => "data" }

    assert_enqueued_with(job: TestHandlerJob, args: [ payload ]) do
      result = EventHandler.route("test.event", payload)
      assert result, "Routing should return true for registered handler"
    end
  end

  test "returns false when routing unknown event type" do
    assert_no_enqueued_jobs do
      result = EventHandler.route("unknown.event", {})
      refute result, "Routing should return false for unknown event type"
    end
  end

  test "supports version-specific handlers" do
    # Register handlers for different versions
    EventHandler.register_handler("api.event", V1HandlerJob, version: "v1")
    EventHandler.register_handler("api.event", V2HandlerJob, version: "v2")

    # Test that version-specific routing works
    test_payload = { "version_test" => true }

    assert_enqueued_with(job: V1HandlerJob, args: [ test_payload ]) do
      EventHandler.route("api.event", test_payload, version: "v1")
    end

    assert_enqueued_with(job: V2HandlerJob, args: [ test_payload ]) do
      EventHandler.route("api.event", test_payload, version: "v2")
    end
  end

  test "falls back to unversioned handler if version-specific one missing" do
    # Register only unversioned handler
    EventHandler.register_handler("fallback.event", FallbackHandlerJob)

    # Should use unversioned handler when trying to route to non-existent v3
    test_payload = { "fallback" => true }

    assert_enqueued_with(job: FallbackHandlerJob, args: [ test_payload ]) do
      result = EventHandler.route("fallback.event", test_payload, version: "v3")
      assert result, "Should fall back to unversioned handler"
    end
  end

  test "handles explicit version in event name" do
    # Register with explicit version string
    EventHandler.register_handler("data.update", VersionedEventHandler, version: "v2")

    # Test matching with fully qualified event name
    test_payload = { "data" => "test" }

    assert_enqueued_with(job: VersionedEventHandler, args: [ test_payload ]) do
      # Pass the fully qualified name to route
      result = EventHandler.route("v2.data.update", test_payload)
      assert result, "Should route to handler using fully qualified event name"
    end
  end

  test "handles non-job handler gracefully" do
    # Register a handler that doesn't respond to perform_later
    invalid_handler = Object.new
    EventHandler.register_handler("invalid.handler", invalid_handler)

    # Should log error and return false
    assert_no_enqueued_jobs do
      result = EventHandler.route("invalid.handler", {})
      refute result, "Should return false for invalid handler"
    end
  end

  test "handles exceptions during routing" do
    EventHandler.register_handler("error.event", ErrorHandlerJob)

    # Should catch exception, log it, and return false
    assert_no_enqueued_jobs do
      result = EventHandler.route("error.event", {})
      refute result, "Should return false when handler raises exception"
    end
  end

  test "passes multiple arguments correctly" do
    EventHandler.register_handler("multi.arg", MultiArgHandlerJob)

    # Test with multiple arguments
    arg1 = { "first" => "arg" }
    arg2 = { "second" => "arg" }
    arg3 = "third_arg"

    assert_enqueued_with(job: MultiArgHandlerJob, args: [ arg1, arg2, arg3 ]) do
      result = EventHandler.route("multi.arg", arg1, arg2, arg3)
      assert result, "Should route with multiple arguments"
    end
  end

  test "works with existing job classes" do
    # Test with actual job classes
    test_payload = {
      "company_droplet" => {
        "fluid_shop" => "test-shop",
        "name" => "Test Company",
        "fluid_company_id" => 123,
        "company_droplet_uuid" => "abc-123-xyz",
        "authentication_token" => "secret-token",
        "webhook_verification_token" => "verify-token",
        "service_company_id" => "service-123",
      },
    }

    # Register the default handlers
    EventHandler.register_handler("company_droplet.created", DropletInstalledJob)

    assert_enqueued_with(job: DropletInstalledJob, args: [ test_payload ]) do
      result = EventHandler.route("company_droplet.created", test_payload)
      assert result, "Should route to DropletInstalledJob"
    end
  end

  test "can register custom handler at runtime" do
    # Register the handler at runtime
    EventHandler.register_handler("custom.runtime", CustomRuntimeHandlerJob)

    # Test routing to the custom handler
    test_payload = { "runtime" => "test" }

    assert_enqueued_with(job: CustomRuntimeHandlerJob, args: [ test_payload ]) do
      result = EventHandler.route("custom.runtime", test_payload)
      assert result, "Should route to custom runtime handler"
    end
  end
end
