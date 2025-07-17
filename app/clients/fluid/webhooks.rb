module Fluid
  module Webhooks
    def webhooks
      @webhooks ||= Resource.new(self)
    end

    class Resource
      def initialize(client)
        @client = client
      end

      def get
        @client.get("/api/company/webhooks")
      end

      def create(attributes = {})
        @client.post("/api/company/webhooks", body: payload(attributes))
      end

      def update(webhook_id, attributes = {})
        @client.put("/api/company/webhooks/#{webhook_id}", body: payload(attributes))
      end

      def delete(webhook_id)
        @client.delete("/api/company/webhooks/#{webhook_id}")
      end

      def payload(attributes = {})
        {
          "webhook" => {
            "resource" => attributes[:resource] || "droplet",
            "url" => attributes[:url] || webhook_url,
            "active" => attributes[:active] || true,
            "auth_token" => attributes[:auth_token] || "secret_token",
            "event" => attributes[:event] || "installed",
            "http_method" => attributes[:http_method] || "post",
          },
        }
      end

    private

      def webhook_url
        Rails.application.routes.url_helpers.webhook_url(host: Setting.host_server.base_url)
      end
    end
  end
end
