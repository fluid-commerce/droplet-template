class ShipstationController < ApplicationController
  skip_before_action :verify_authenticity_token, only: %i[ export notify ]
  before_action :authenticate

  # GET /shipstation
  def export
    # Fetch orders from Fluid Commerce API
    # Note: need to consider the `start_date=[Start Date]&end_date=[End Date]&page=1` that Shipstation stated in doc
    fluid_client = FluidClient.new
    orders = fluid_client.get("/api/v2/orders?page=1&per_page=10")

    # Convert orders to ShipStation XML format
    xml_response = generate_shipstation_xml(orders["orders"])

    render xml: xml_response, content_type: "application/xml"
  end

  # POST /shipstation
  def notify
    # Extract XML payload from request
    xml_data = Nokogiri::XML(request.body.read)

    order_id = xml_data.at_xpath("//OrderID")&.text
    tracking_number = xml_data.at_xpath("//TrackingNumber")&.text
    shipping_carrier = xml_data.at_xpath("//Carrier")&.text

    items = []
    xml_data.xpath("//Item").each do |item|
      item_id = item.at_xpath("./ItemID")&.text
      quantity = item.at_xpath("./Quantity")&.text.to_i

      items << {
        item_id: item_id,
        quantity: quantity,
      } if item_id.present? && quantity.present?
    end

    # Construct payload for Fluid Commerce API
    payload = {
      order_id: order_id,
      order_items: items,
      tracking_informations: [
        {
          tracking_number: tracking_number,
          shipping_carrier: shipping_carrier,
        },
      ],
    }

    # Post to Fluid Commerce API
    begin
      fluid_client = FluidClient.new
      response = fluid_client.post("/api/order_fulfillments", body: payload)
      render json: { success: true, message: "Order fulfillment submitted successfully", data: response }, status: :ok
    rescue StandardError => e
      Rails.logger.error("Failed to submit order fulfillment: #{e.message}")
      render json: { success: false, error: e.message }, status: :unprocessable_entity
    end
  end

private

  def authenticate
    authenticate_or_request_with_http_basic do |username, password|
      # NOTE: For this, do we allow the user to set their own username and password and save it in the settings?
      # For that, we need to have company id in the query param. But not sure that Shipstation would allow that.
      ActiveSupport::SecurityUtils.secure_compare(username, "shipstation_user") &&
        ActiveSupport::SecurityUtils.secure_compare(password, "shipstation_password")
    end
  end

  def generate_shipstation_xml(orders)
    builder = Nokogiri::XML::Builder.new(encoding: "UTF-8") do |xml|
      xml.Orders do
        orders.each do |order|
          xml.Order do
            # Order details
            xml.OrderID order["id"].to_s
            xml.OrderNumber order["order_number"].to_s
            xml.OrderDate Time.parse(order["created_at"].to_s).strftime("%m/%d/%Y %H:%M")
            xml.OrderStatus map_order_status(order["status"])
            xml.ShippingMethod "" # TODO: we don't have in our order response
            xml.PaymentMethod "" # TODO: we don't have in our order response
            xml.OrderTotal order["total"].to_s
            xml.TaxAmount order["tax"].to_s
            xml.ShippingAmount order.dig("shipping") || "0.00"
            xml.CustomerNotes order["note"].to_s # TODO: is this really the customer notes?
            xml.InternalNotes "" # TODO: we don't have in our order response

            # Customer details
            if order["customer"].present?
              xml.Customer do
                xml.CustomerCode "" # TODO: we don't have in our order response

                # Billing address
                if order["bill_to"].present?
                  xml.BillTo do
                    xml.Name order.dig("bill_to", "name").to_s
                    xml.Company "" # TODO: we don't have in our order response
                    xml.Address1 order.dig("bill_to", "address1").to_s
                    xml.Address2 order.dig("bill_to", "address2").to_s
                    xml.City order.dig("bill_to", "city").to_s
                    xml.State order.dig("bill_to", "state").to_s
                    xml.PostalCode order.dig("bill_to", "postal_code").to_s
                    xml.Country order.dig("bill_to", "country_code").to_s
                    xml.Phone "" # TODO: we don't have in our order response
                    xml.Email "" # TODO: we don't have in our order response
                  end
                end

                # Shipping address
                if order["ship_to"].present?
                  xml.ShipTo do
                    xml.Name order.dig("ship_to", "name").to_s
                    xml.Company "" # TODO: we don't have in our order response
                    xml.Address1 order.dig("ship_to", "address1").to_s
                    xml.Address2 order.dig("ship_to", "address2").to_s
                    xml.City order.dig("ship_to", "city").to_s
                    xml.State order.dig("ship_to", "state").to_s
                    xml.PostalCode order.dig("ship_to", "postal_code").to_s
                    xml.Country order.dig("ship_to", "country_code").to_s
                    xml.Phone "" # TODO: we don't have in our order response
                  end
                end
              end
            end

            # Items in the order
            if order["items"].present?
              xml.Items do
                order["items"].each do |item|
                  xml.Item do
                    xml.SKU item["sku"].to_s
                    xml.Name item["title"].to_s
                    xml.Quantity item["quantity"].to_s
                    xml.UnitPrice item["price"].to_s
                    xml.Weight "" # TODO: we don't have in our order response
                    xml.WeightUnits "" # TODO: we don't have in our order response

                    # Product options/variants
                    if item["options"].present?
                      xml.Options do
                        item["options"].each do |option|
                          xml.Option do
                            xml.Name option["name"].to_s
                            xml.Value option["value"].to_s
                          end
                        end
                      end
                    end
                  end
                end
              end
            end
          end
        end
      end
    end

    # Return the XML as a string with CDATA sections
    xml_with_cdata = builder.to_xml
    apply_cdata_sections(xml_with_cdata)
  end

  def apply_cdata_sections(xml_string)
    # Fields that should have CDATA wrappers
    cdata_fields = %w[
      OrderNumber OrderID CustomerCode
      Name Company Address1 Address2 City State PostalCode Country Phone Email
      SKU ShippingMethod PaymentMethod CustomerNotes InternalNotes
    ]

    # Apply CDATA sections to these fields
    doc = Nokogiri::XML(xml_string)
    cdata_fields.each do |field|
      doc.xpath("//#{field}").each do |node|
        next if node.children.empty?

        content = node.content
        node.content = ""
        node.add_child(Nokogiri::XML::CDATA.new(doc, content))
      end
    end

    doc.to_xml
  end

  def map_order_status(fluid_status)
    # Map Fluid Commerce order statuses to ShipStation expected statuses
    # { awaiting_payment: 0, awaiting_shipment: 1, shipped: 2, delivered: 3, archived: 4, cancelled: 5, failed_payment: 6, draft: 7 } # rubocop:disable Layout/LineLength
    case fluid_status
    when "awaiting_payment"
      "unpaid"
    when "awaiting_shipment"
      "paid"
    when "shipped"
      "shipped"
    when "cancelled"
      "cancelled"
    else
      "on_hold"
    end
  end
end
