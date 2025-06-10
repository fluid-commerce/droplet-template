class UPaymentsOrderPayloadGenerator

  attr_reader :cart, :external_id

  def initialize(cart:, external_id:)
    @cart = ActiveSupport::HashWithIndifferentAccess.new(cart)
    @external_id = external_id
  end

  def self.generate_order_payload(cart:, external_id:)
    new(cart:, external_id:).generate_order_payload
  end

  def generate_order_payload
    {
      invoiceNumber: Time.now.to_i.to_s,
      totalAmount: cart[:amount_total],
      tipAmount: nil,
      exciseTax: nil,
      salesTax: cart[:tax_total],
      serviceFee: nil,
      currency: cart[:currency_code],
      toAccountNumber: nil,
      redirectUrl: "https://a3974a96b39c.ngrok.app/checkout_callback",
      cancelUrl: "https://lvh.me:3300/checkout_callback",
      orderTime: Time.now.to_i.to_s,
      paymentMode: nil,
      externalId: external_id,
      language: cart[:language_iso],
      tipAllowed: false,
      autoshipRequired: false,
      joinDate: nil,
      personType: nil,
      rankType: nil,
      layers: nil,
      shippingInformation: {
        AddressLine1: cart[:ship_to][:address1],
        AddressLine2: cart[:ship_to][:address2],
        city: cart[:ship_to][:city],
        country: cart[:ship_to][:country_code],
        emailaddress: cart[:ship_to][:email],
        recipientName: cart[:ship_to][:name],
        postalCode: cart[:ship_to][:postal_code],
        phoneNumber: nil,
        state: cart[:ship_to][:state]
        # shippingType:   #Same Day = SD, Next Day = ND, Second Day = 2D, Standard = ST, Delivery = DE, Pick-up = PU
      },
      productDetails: [
        cart[:items].map do |item|
          {
              productId: item[:product_id],
              description: item[:product_title],
              quantity: item[:quantity],
              unitPrice: item[:price].to_f
          }
        end
      ]
    }
  end
end
