class CheckoutCallbackController < ApplicationController
  def get_redirect_url
    user = UPaymentsUserApiClient.check_user_exists(
      email: callback_params[:email],
      external_id: callback_params[:external_id]
    )

    if user["data"].empty?
      user_payload = UPaymentsConsumerPayloadGenerator.generate_consumer_payload(
        cart: cart_payload,
        external_id: callback_params[:external_id]
      )
      user = UPaymentsUserApiClient.onboard_consumer(payload: user_payload)
    end

    order_payload = UPaymentsOrderPayloadGenerator.generate_order_payload(
      cart: cart_payload,
      external_id: callback_params[:external_id],
      payment_account_id: callback_params[:payment_account_id]
    )

    redirect_url = UPaymentsCheckoutApiClient.create_order(payload: order_payload)

    uuid = user.dig("data", "uuid")
    base_redirect_url = redirect_url.dig("data", "redirectUrl")
    final_redirect_url = "#{base_redirect_url}&uuid=#{uuid}"

    render json: { redirect_url: final_redirect_url }
  end

  def success
    debugger
    if success_params[:status] == "SUCCESS"
      cart_token = success_params[:cart_token]
      payment_account_id = success_params[:payment_account_id]
      # Call the fluid payment_account api to create the payment
      # api/v202506/payments/{payment_account_id}?cart_token={cart_token}
      # The response will contain the uuid of the payment inside Fluid.

      # Then request the POST `/api/carts/{cart_token}/checkout?payment_uuid={payment_uuid}`
      # Redirect to `response[:order][:redirect_url]`
    else
    end
  end

private

  def callback_params
    params.permit(:cart, :external_id, :payment_account_id)
  end

  def success_params
    params.permit(:cart_token, :payment_account_id, :status)
  end

  # dummy cart payload to test the checkout callback
  def cart_payload
    {
      id: 82,
      agreements: [],
      amount_total: 0.392e3,
      amount_total_in_currency: "$392.00",
      attribution: nil,
      available_payment_methods:
        [ { id: 11,
          type: "credit_card",
          name: "Credit Card",
          supported_brands: %w[visa master american_express discover],
          test: true,
          sandbox: true,
          bogus_gateway: false,
          tokenize_path: nil,
          apple_pay: false,
          apple_pay_merchant_identifier: nil, },
        { id: 2,
          type: "credit_card",
          name: "Credit Card",
          supported_brands: [],
          test: true,
          sandbox: true,
          bogus_gateway: false,
          tokenize_path: nil,
          apple_pay: false,
          apple_pay_merchant_identifier: nil, },
        { id: 10, type: "affirm", name: "Affirm", public_api_key: "S5G02G2LOY9H3RTK", test: true, sandbox: true },
        { id: 4, type: "bread", name: "Bread", integration_key: "a21603f7-93b5-4382-ad45-112a77de9391", test: false,
sandbox: true, }, ],
      available_shipping_methods: [],
      bill_to:
        { id: 980191324,
        address1: nil,
        address2: nil,
        address3: nil,
        city: nil,
        country_code: "US",
        default: false,
        first_name: nil,
        last_name: nil,
        name: nil,
        postal_code: "042343",
        state: nil,
        subdivision_code: nil, },
      buyer_rep_id: 1,
      cart_token: "ct_4wgvcJhTzj9qdEO9bO0vZK",
      company:
        { id: 980190962,
        checkout_primary_button_color: nil,
        checkout_primary_text_color: nil,
        checkout_secondary_button_color: nil,
        checkout_secondary_text_color: nil,
        collect_phone: nil,
        fluid_shop: nil,
        logo_url: "https://cdn.filestackcontent.com/1Rnqia44T2mLcXuFZCTV",
        name: "Fluid",
        primary_domain_hostname: "lvh.me",
        require_billing_zip: false,
        require_phone: false,
        subdomain: "fluid", },
      country: { id: 214, iso: "US", name: "United States", province_required: false },
      currency_code: "USD",
      currency_symbol: "$",
      cv_total: 6,
      digital_only: true,
      discount_code: nil,
      discount_total: 0.0,
      discount_total_in_currency: "$0.00",
      email: "sachin+tb11@gmail.com",
      enrollment_fee: 0.0,
      enrollment_fee_in_currency: "$0.00",
      enrollment_pack: nil,
      enrollment_pack_id: nil,
      immutable_items: false,
      items:
        [ { id: 116,
          allow_subscription: true,
          cv: 6,
          discount_amount: 0.0,
          discount_amount_in_currency: "$0.00",
          display_to_customer: true,
          enrollment: false,
          enrollment_pack_id: nil,
          errors: nil,
          price: 0.75e2,
          price_in_currency: "$75.00",
          product:
          { id: 189,
            cv: 0,
            image_path: nil,
            image_url: "https://d1r16g5m5p3ba7.cloudfront.net/uploads/product/image/298486374/beautyrest.png",
            price: 0.1826e2,
            price_in_currency: "$18.26",
            sku: "ULTR0FVX5E",
            tax: 0.0,
            tax_in_currency: "$0.00",
            title: "Investor Communications Supervisor1", },
          product_title: "Investor Communications Supervisor1",
          quantity: 1,
          qv: 231,
          subscribe_and_save: nil,
          subscribe_and_save_for_display: nil,
          subscribe_and_save_in_currency: nil,
          subscription: false,
          subscription_interval: nil,
          subscription_interval_unit: nil,
          subscription_only: false,
          subscription_plan_id: nil,
          subscription_plans: [],
          subscription_price: 0.25e2,
          subscription_price_in_currency: "$25.00",
          subscription_start: nil,
          tax: 0.317e3,
          tax_in_currency: "$317.00",
          title: nil,
          variant:
          { id: 89,
            image_path: nil,
            image_url: nil,
            options: [],
            price: 0.25e2,
            price_in_currency: "$25.00",
            primary_image: nil,
            sku: "Neque temporibus et nam minima consequuntur officia non minus.",
            title: "Default Variant", }, } ],
      language_iso: nil,
      payment_method:
        { id: 48,
        type: "CreditCard",
        payment_method_type: "visa",
        last_four: "1111",
        exp_month: "12",
        exp_year: "2028",
        logo_url: "https://assets.fluid.app/images/payment_icons/visa.svg", },
      phone: "+18123432334",
      processed: true,
      qv_total: 231,
      recurring: [],
      ship_to:
        { id: 980191323,
        address1: "A Admiralty Dr W",
        address2: "",
        address3: nil,
        city: "Middletown",
        country_code: "US",
        default: true,
        first_name: "Keagan",
        last_name: "VonRueden",
        name: "Keagan VonRueden",
        postal_code: "02842",
        state: "Arizona",
        subdivision_code: nil, },
      shipping_method: nil,
      shipping_total: "Free",
      shipping_total_for_display: "Free",
      shipping_total_in_currency: "$0.00",
      state: "complete",
      sub_total: 0.75e2,
      sub_total_in_currency: "$75.00",
      tax_total: 0.317e3,
      tax_total_in_currency: "$317.00",
      transaction_fee: 0.0,
      transaction_fee_in_currency: "$0.00",
      type: "regular",
      valid_for_checkout: false,
    }
  end
end
