module TopologicalInventory
  module Satellite
    module Connection
      class << self
        def connection(account_number, receptor_node_id)
          self.account_number = account_number
          self.node_id        = receptor_node_id
          @connection         = Faraday.new(receptor_controller_url, headers: identity_header)
        end

        def status
          url = receptor_controller_url("/connection/status")
          body = {"account" => account_number, "node_id" => node_id}.to_json
          response = Faraday.post(url, body, identity_header)
          JSON.parse(resp.body)["status"]
        end

        private

        attr_accessor :account_number, :node_id
        attr_reader   :connection

        def receptor_controller_url(endpoint)
          endpoint = "/#{endpoint}" unless endpoint[0] == "/"

          "#{receptor_controller_base_url}#{endpoint}"
        end

        def receptor_controller_base_url
          scheme = ENV["RECEPTOR_CONTROLLER_SCHEME"] || "http"
          host   = ENV["RECEPTOR_CONTROLLER_HOST"] || "localhost"
          port   = ENV["RECEPTOR_CONTROLLER_PORT"] || "9090"

          "#{scheme}://#{host}:#{port}"
        end

        def identity_header(account_number)
          {
            "x-rh-identity" => Base64.strict_encode64(
              {"identity" => {"account_number" => account_number}}.to_json
            )
          }
        end
      end
    end
  end
end
