module Fluid
  module Callbacks
    def callbacks
      @callbacks ||= Resource.new(self)
    end

    class Resource
      def initialize(client)
        @client = client
      end

      def get
        @client.get("/api/company/callbacks")
      end

      def create(attributes = {})
        @client.post("/api/company/callbacks", body: payload(attributes))
      end

      def update(callback_id, attributes = {})
        @client.put("/api/company/callbacks/#{callback_id}", body: payload(attributes))
      end

      def delete(callback_id)
        @client.delete("/api/company/callbacks/#{callback_id}")
      end

      def payload(attributes = {})
        {
          "callback_registration" => {
            "definition_name" => attributes[:definition_name],
            "url" => attributes[:url],
            "timeout_in_seconds" => attributes.key?(:timeout_in_seconds) ? attributes[:timeout_in_seconds] : 20,
            "active" => attributes.key?(:active) ? attributes[:active] : true,
          },
        }
      end

    private

      def callback_url(definition_name = "update_cart_tax")
        Rails.application.routes.url_helpers.api_v1_callback_url(
          definition_name: definition_name,
          host: Setting.host_server.base_url,
        )
      end
    end
  end
end
