class ByDesign
  attr_reader :cart, :sponsor_rep_id
  include HTTParty

  base_uri ENV["BY_DESIGN_API_URL"]

  def initialize(cart:, sponsor_rep_id:)
    @cart = ActiveSupport::HashWithIndifferentAccess.new(cart)
    @sponsor_rep_id = sponsor_rep_id
  end

  def self.create_consumer(cart:, sponsor_rep_id:)
    new(cart:, sponsor_rep_id:).create_consumer
  end

  def create_consumer
    response = self.class.post(
      "/api/rep/Create",
      headers: headers,
      body: generate_consumer_payload.to_json
    )

    if response.code == 200
      JSON.parse(response.body)
    else
      { Result: { IsSuccessful: false, Message: response.body } }
    end
  end

  private
  def headers
    { 'Authorization': authorization, 'Content-Type': "application/json", 'Accept': "application/json" }
  end

  def authorization
    "Basic #{Base64.strict_encode64("#{ENV["BY_DESIGN_INTEGRATION_USERNAME"]}:#{ENV["BY_DESIGN_INTEGRATION_PASSWORD"]}").strip}"
  end

  def generate_consumer_payload
    {
      SponsorRepDID: sponsor_rep_id
      FirstName: cart[:ship_to][:first_name],
      LastName: cart[:ship_to][:last_name],
      Email: cart[:email],
      ShipStreet1: cart[:ship_to][:address1],
      ShipStreet2: cart[:ship_to][:address2],
      ShipCity: cart[:ship_to][:city],
      ShipState: cart[:ship_to][:state],
      ShipPostalCode: cart[:ship_to][:postal_code],
      ShipCountry: cart[:ship_to][:country_code],
    }
  end
end
