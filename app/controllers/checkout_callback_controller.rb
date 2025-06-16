class CheckoutCallbackController < ApplicationController
  skip_before_action :verify_authenticity_token

  def get_redirect_url
    user = UPaymentsUserApiClient.check_user_exists(
      email: callback_params[:cart][:email],
      external_id: external_id
    )

    if user["data"].blank?
      user_payload = UPaymentsConsumerPayloadGenerator.generate_consumer_payload(
        cart: cart_payload,
        external_id: external_id
      )
      user = UPaymentsUserApiClient.onboard_consumer(payload: user_payload)
    end

    order_payload = UPaymentsOrderPayloadGenerator.generate_order_payload(
      cart: cart_payload,
      external_id: external_id,
      payment_account_id: callback_params[:payment_account_id]
    )

    redirect_url = UPaymentsCheckoutApiClient.create_order(payload: order_payload)

    # TODO: need to hanlde error when `data` is not present
    uuid = user.dig("data", "uuid")
    base_redirect_url = redirect_url.dig("data", "redirectUrl")
    final_redirect_url = "#{base_redirect_url}&uuid=#{uuid}"

    render json: { redirect_url: final_redirect_url }
  end

  def success
    if success_params[:status] == "SUCCESS"
      cart_token = success_params[:cart_token]
      payment_account_id = success_params[:payment_account_id]

      fluid_client = FluidClient.new

      # Call the fluid checkout api to create payment and payment_methods
      payment_payload = {
        cart_token: cart_token,
        payment_method: {
          integration_class: "Droplet",
          source: "droplet",
        },
      }
      payment_response = fluid_client.post("/api/v202506/payments/#{payment_account_id}", body: payment_payload)
      payment_uuid = payment_response["payment"]["uuid"]

      # Call the fluid checkout api to create the order
      checkout_response = fluid_client.post("/api/carts/#{cart_token}/checkout?payment_uuid=#{payment_uuid}")

      redirect_url = checkout_response["order"]["redirect_url"]
      redirect_to redirect_url
    else
      fluid_checkout_url = "#{ENV['FLUID_HOST_URL']}/checkouts/#{cart_token}"
      redirect_to fluid_checkout_url
    end
  end

private

  def external_id
    if callback_params[:customer].present? && callback_params[:customer][:external_id].present?
      "C#{callback_params[:customer][:external_id]}" # TODO: not sure whether we need to add C prefix
    else
      "R#{callback_params[:user_company][:external_id]}"
    end
  end

  def callback_params
    params.permit(
      :payment_account_id,
      customer: {},
      user_company: {},
      cart: [
        :cart_token,
        :amount_total,
        :tax_total,
        :currency_code,
        :language_iso,
        :recurring,
        :email,
        ship_to: %i[
          first_name
          last_name
          address1
          address2
          city
          state
          postal_code
          country_code
          email
          name
        ],
        items: [
          :product_title,
          :quantity,
          :price,
          { product: [ :sku ] },
        ],
      ]
    )
  end

  def success_params
    params.permit(:cart_token, :payment_account_id, :status)
  end

  def cart_payload
    callback_params[:cart]
  end
end
