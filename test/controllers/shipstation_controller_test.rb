require "test_helper"

class ShipstationControllerTest < ActionDispatch::IntegrationTest
  def valid_auth_header
    credentials = ActionController::HttpAuthentication::Basic.encode_credentials("shipstation_user",
"shipstation_password")
    { "Authorization" => credentials }
  end

  def invalid_auth_header
    credentials = ActionController::HttpAuthentication::Basic.encode_credentials("wrong_user", "wrong_password")
    { "Authorization" => credentials }
  end

  test "should get export with valid credentials" do
    # Mock the FluidClient to prevent API calls during tests
    FluidClient.any_instance.stubs(:get).with("/api/v2/orders?page=1&per_page=10").returns({
      "orders" => [
        {
          "id" => "12345",
          "order_number" => "ORD-123",
          "status" => "processing",
          "created_at" => "2023-01-01T12:00:00Z",
          "updated_at" => "2023-01-02T12:00:00Z",
          "total" => "49.99",
          "tax" => "5.00",
          "shipping" => "10.00",
          "note" => "Test order",
          "customer" => "Keagan Romanov",
          "items" => [
            {
              "sku" => "PROD-123",
              "title" => "Test Product",
              "quantity" => "1",
              "price" => "44.99",
            },
          ],
          "bill_to" => {
            "name" => "Keagan Romanov",
            "address1" => "123 Main St",
            "city" => "Anytown",
            "state" => "CA",
            "postal_code" => "12345",
            "country_code" => "US",
          },
          "ship_to" => {
            "name" => "Keagan Romanov",
            "address1" => "123 Main St",
            "city" => "Anytown",
            "state" => "CA",
            "postal_code" => "12345",
            "country_code" => "US",
          },
        },
      ],
    })

    get "/shipstation", headers: valid_auth_header
    assert_response :success
    assert_equal "application/xml", @response.media_type

    # Check if response is valid XML
    xml_doc = Nokogiri::XML(@response.body)
    assert_nil xml_doc.errors.first

    # Check for basic structure and content
    assert_equal "Orders", xml_doc.root.name
    assert_equal "12345", xml_doc.at_xpath("//OrderID").text
  end

  test "should reject export with invalid credentials" do
    get "/shipstation", headers: invalid_auth_header
    assert_response :unauthorized
  end

  test "should reject export without credentials" do
    get "/shipstation"
    assert_response :unauthorized
  end

  test "should post notify with valid credentials" do
    FluidClient.any_instance.stubs(:post).with("/api/order_fulfillments", anything).returns({ "success" => true })

    # Create a sample XML payload that ShipStation would send
    xml_payload = <<~XML
      <?xml version="1.0" encoding="utf-8"?>
      <ShipNotice>
        <OrderID>12345</OrderID>
        <TrackingNumber>1Z9999999999999999</TrackingNumber>
        <Carrier>UPS</Carrier>
        <Items>
          <Item>
            <ItemID>789</ItemID>
            <Quantity>2</Quantity>
          </Item>
          <Item>
            <ItemID>456</ItemID>
            <Quantity>1</Quantity>
          </Item>
        </Items>
      </ShipNotice>
    XML

    post "/shipstation", params: xml_payload, headers: valid_auth_header.merge("CONTENT_TYPE" => "application/xml")
    assert_response :success

    response_json = JSON.parse(response.body)
    assert_equal true, response_json["success"]
    assert_equal "Order fulfillment submitted successfully", response_json["message"]
  end

  test "should handle notify with invalid XML" do
    # Mock the FluidClient to prevent API calls during tests
    FluidClient.any_instance.stubs(:post).raises(StandardError.new("Invalid request"))

    # Create an invalid XML payload
    xml_payload = "<?xml version=\"1.0\" encoding=\"utf-8\"?><Invalid>"

    post "/shipstation", params: xml_payload, headers: valid_auth_header.merge("CONTENT_TYPE" => "application/xml")
    assert_response :unprocessable_entity

    response_json = JSON.parse(response.body)
    assert_equal false, response_json["success"]
    assert response_json["error"].present?
  end

  test "should verify correct payload is sent to Fluid API" do
    # Expected payload that should be sent to the Fluid API
    expected_payload = {
      order_id: "12345",
      order_items: [
        { item_id: "789", quantity: 2 },
        { item_id: "456", quantity: 1 },
      ],
      tracking_informations: [
        { tracking_number: "1Z9999999999999999", shipping_carrier: "UPS" },
      ],
    }

    # Mock the FluidClient with more specific expectations
    mock_client = mock("FluidClient")
    FluidClient.stubs(:new).returns(mock_client)
    mock_client.expects(:post).with("/api/order_fulfillments", body: expected_payload).returns({ "success" => true })

    # Sample XML payload
    xml_payload = <<~XML
      <?xml version="1.0" encoding="utf-8"?>
      <ShipNotice>
        <OrderID>12345</OrderID>
        <TrackingNumber>1Z9999999999999999</TrackingNumber>
        <Carrier>UPS</Carrier>
        <Items>
          <Item>
            <ItemID>789</ItemID>
            <Quantity>2</Quantity>
          </Item>
          <Item>
            <ItemID>456</ItemID>
            <Quantity>1</Quantity>
          </Item>
        </Items>
      </ShipNotice>
    XML

    post "/shipstation", params: xml_payload, headers: valid_auth_header.merge("CONTENT_TYPE" => "application/xml")
    assert_response :success
  end

  test "should reject notify with invalid credentials" do
    post "/shipstation", headers: invalid_auth_header
    assert_response :unauthorized
  end

  test "should reject notify without credentials" do
    post "/shipstation"
    assert_response :unauthorized
  end
end
