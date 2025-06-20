class CheckoutCallbackController < ApplicationController
  skip_before_action :verify_authenticity_token

  def get_redirect_url
    consumer_external_id = external_id
    user = UPaymentsUserApiClient.check_user_exists(
      email: callback_params[:cart][:email],
      external_id: consumer_external_id
    )

    if user["data"].blank?
      # Create consumer in ByDesign
      by_design_consumer = ByDesign.create_consumer(
        cart: cart_payload,
        sponsor_rep_id: callback_params[:attributable_rep_id]
      )
      consumer_external_id = by_design_consumer["RepDID"].to_s

      # Create customer in Fluid
      fluid_client.post("/api/customers", body: customer_payload.merge(external_id: consumer_external_id))

      # Create consumer in UPayments
      user_payload = UPaymentsConsumerPayloadGenerator.generate_consumer_payload(
        cart: cart_payload,
        external_id: consumer_external_id
      )
      user = UPaymentsUserApiClient.onboard_consumer(payload: user_payload)
    end

    order_payload = UPaymentsOrderPayloadGenerator.generate_order_payload(
      cart: cart_payload,
      external_id: consumer_external_id,
      payment_account_id: callback_params[:payment_account_id]
    )

    redirect_url = UPaymentsCheckoutApiClient.create_order(payload: order_payload)

    # TODO: need to handle error when `data` is not present
    uuid = user.dig("data", "uuid")
    base_redirect_url = redirect_url.dig("data", "redirectUrl")
    final_redirect_url = "#{base_redirect_url}&uuid=#{uuid}"

    render json: { redirect_url: final_redirect_url }
  end

  def success
    if success_params[:status] == "SUCCESS"
      cart_token = success_params[:cart_token]
      payment_account_id = success_params[:payment_account_id]

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

      order_confirmation_url = checkout_response["order"]["order_confirmation_url"]
      redirect_to order_confirmation_url, allow_other_host: true
    else
      fluid_checkout_url = "#{ENV['FLUID_HOST_URL']}/checkouts/#{cart_token}"
      redirect_to fluid_checkout_url, allow_other_host: true
    end
  end

private

  def external_id
    if callback_params[:customer].present? && callback_params[:customer][:external_id].present?
      "C#{callback_params[:customer][:external_id]}" # TODO: not sure whether we need to add C prefix
    elsif callback_params[:user_company].present? && callback_params[:user_company][:external_id].present?
      "R#{callback_params[:user_company][:external_id]}"
    end
  end

  def callback_params
    params.permit(
      :payment_account_id,
      :attributable_rep_id,
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

  def fluid_client
    @fluid_client ||= FluidClient.new
  end

  def customer_payload
    {
      first_name: cart_payload[:ship_to][:first_name],
      last_name: cart_payload[:ship_to][:last_name],
      email: cart_payload[:email],
      notes: "Created by NewULife Payment Redirect Droplet",
      default_address_attributes: {
        address1: cart_payload[:ship_to][:address1],
        address2: cart_payload[:ship_to][:address2],
        city: cart_payload[:ship_to][:city],
        state: cart_payload[:ship_to][:state],
        postal_code: cart_payload[:ship_to][:postal_code],
        country_code: cart_payload[:ship_to][:country_code],
        default: true
      },
      customer_notes_attributes: [
        {
          note: "Created by NewULife Payment Redirect Droplet"
        }
      ]
    }
  end
end
