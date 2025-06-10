class UPaymentsConsumerPayloadGenerator

  attr_reader :cart, :external_id

  def initialize(cart:, external_id:)
    @cart = ActiveSupport::HashWithIndifferentAccess.new(cart)
    @external_id = external_id
  end

  def self.generate_consumer_payload(cart:, external_id:)
    new(cart:, external_id:).generate_consumer_payload
  end

  def generate_consumer_payload
    {
      first_name: cart[:ship_to][:first_name],
      last_name: cart[:ship_to][:last_name],
      email: cart[:email],
      phone: nil,
      product_uuid: '1234567890',
      dob: nil,
      address1: cart[:ship_to][:address1],
      address2: cart[:ship_to][:address2],
      city: cart[:ship_to][:city],
      state: cart[:ship_to][:state],
      zipcode: cart[:ship_to][:postal_code],
      country_code: '+1',
      ssn: nil,
      primaryWallet: nil,
      business_name: nil,
      external_id: external_id,
      currency: ["USD","JPY","HKD","TWD","MYR","SGD","KRW","EUR","GBP","CNY"],
      hkcm: false,
    }
  end
end
