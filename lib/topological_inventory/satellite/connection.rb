require "faraday"

module TopologicalInventory
  module Satellite
    class Connection
      class << self
        def connection(account_number, receptor_node_id)
          new(account_number, receptor_node_id)
        end
      end

      def initialize(account_number, node_id)
        self.account_number = "0000001" #account_number
        self.node_id        = node_id
      end

      def status
        url = receptor_controller_url("/connection/status")
        body = {"account" => account_number, "node_id" => node_id}.to_json
        response = Faraday.post(url, body, identity_header(account_number))
        # puts "BODY: #{body}, RESPONSE: #{response.body}"
        JSON.parse(response.body)["status"]
      end

      def send_availability_check(caller, source_uid, receptor_node_id, response_worker)
        url = receptor_controller_url("/job")

        body = {
          :account   => account_number,
          :recipient => receptor_node_id,
          :payload   => {'satellite_instance_id' => source_uid.to_s}.to_json,
          :directive => "receptor_satellite:health_check"
        }
        # puts body
        response = Faraday.post(url, body.to_json, identity_header(account_number))
        msg_id = JSON.parse(response.body)['id']

        # response in Source.availability_check_response
        response_worker.register_msg_id(msg_id, caller, :availability_check_response)
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

      # org_id with any number is required by receptor controller
      def identity_header(account_number)
        {
          "x-rh-identity" => Base64.strict_encode64(
            {"identity" => {"account_number" => account_number, "internal" => {"org_id" => '000001'}}}.to_json
          )
        }
      end
    end
  end
end
