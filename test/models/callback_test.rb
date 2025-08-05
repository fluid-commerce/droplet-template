require "test_helper"

class CallbackTest < ActiveSupport::TestCase
  def setup
    @valid_callback = {
      name: "test_callback",
      description: "Test callback description",
      url: "https://example.com/webhook",
      timeout_in_seconds: 10,
      example_response: { test: "response" },
      request_schema: { type: "object" },
      response_schema: { type: "object" },
      active: true,
    }
  end

  test "should be valid with valid attributes" do
    callback = ::Callback.new(@valid_callback)
    assert callback.valid?
  end

  test "should require name" do
    callback = ::Callback.new(@valid_callback.except(:name))
    assert_not callback.valid?
    assert_includes callback.errors[:name], "can't be blank"
  end

  test "should require unique name" do
    ::Callback.create!(@valid_callback)
    callback = ::Callback.new(@valid_callback)
    assert_not callback.valid?
    assert_includes callback.errors[:name], "has already been taken"
  end

  test "should require description" do
    callback = ::Callback.new(@valid_callback.except(:description))
    assert_not callback.valid?
    assert_includes callback.errors[:description], "can't be blank"
  end

  test "should require example_response" do
    callback = ::Callback.new(@valid_callback.except(:example_response))
    assert_not callback.valid?
    assert_includes callback.errors[:example_response], "can't be blank"
  end

  test "should require request_schema" do
    callback = ::Callback.new(@valid_callback.except(:request_schema))
    assert_not callback.valid?
    assert_includes callback.errors[:request_schema], "can't be blank"
  end

  test "should require response_schema" do
    callback = ::Callback.new(@valid_callback.except(:response_schema))
    assert_not callback.valid?
    assert_includes callback.errors[:response_schema], "can't be blank"
  end

  test "should validate active boolean" do
    callback = ::Callback.new(@valid_callback.merge(active: nil))
    assert_not callback.valid?
    assert_includes callback.errors[:active], "is not included in the list"
  end

  test "should validate timeout_in_seconds range" do
    callback = ::Callback.new(@valid_callback.merge(timeout_in_seconds: 0))
    assert_not callback.valid?
    assert_includes callback.errors[:timeout_in_seconds], "must be greater than 0"

    callback = ::Callback.new(@valid_callback.merge(timeout_in_seconds: 21))
    assert_not callback.valid?
    assert_includes callback.errors[:timeout_in_seconds], "must be less than or equal to 20"
  end

  test "should accept valid JSON objects" do
    callback = ::Callback.new(@valid_callback)
    assert callback.valid?
  end

  test "should reject invalid JSON in example_response" do
    callback = ::Callback.new(@valid_callback.merge(example_response: "invalid json"))
    assert_not callback.valid?
    assert_includes callback.errors[:example_response], "must be a valid JSON object"
  end

  test "should reject invalid JSON in request_schema" do
    callback = ::Callback.new(@valid_callback.merge(request_schema: "invalid json"))
    assert_not callback.valid?
    assert_includes callback.errors[:request_schema], "must be a valid JSON object"
  end

  test "should reject invalid JSON in response_schema" do
    callback = ::Callback.new(@valid_callback.merge(response_schema: "invalid json"))
    assert_not callback.valid?
    assert_includes callback.errors[:response_schema], "must be a valid JSON object"
  end

  test "should not allow active without URL" do
    callback = ::Callback.new(@valid_callback.merge(url: nil))
    assert_not callback.valid?
    assert_includes callback.errors[:active], "cannot be enabled without a URL"
  end

  test "should not allow active without timeout" do
    callback = ::Callback.new(@valid_callback.merge(timeout_in_seconds: nil))
    assert_not callback.valid?
    assert_includes callback.errors[:active], "cannot be enabled without a timeout"
  end

  test "should not allow active with empty URL" do
    callback = ::Callback.new(@valid_callback.merge(url: ""))
    assert_not callback.valid?
    assert_includes callback.errors[:active], "cannot be enabled without a URL"
  end

  test "should allow inactive without URL and timeout" do
    callback = ::Callback.new(@valid_callback.merge(active: false, url: nil, timeout_in_seconds: nil))
    assert callback.valid?
  end

  test "should allow active with URL and timeout" do
    callback = ::Callback.new(@valid_callback)
    assert callback.valid?
  end

  test "active scope should return only active callbacks" do
    active_callback = ::Callback.create!(@valid_callback)
    inactive_callback = ::Callback.create!(@valid_callback.merge(name: "inactive", active: false))

    assert_includes ::Callback.active, active_callback
    assert_not_includes ::Callback.active, inactive_callback
  end


end
