require "faraday"
require "manageiq-messaging"

module TopologicalInventory
  module Satellite
    module Receptor
      class Client
        require "topological_inventory/satellite/receptor/client/configuration"
        require "topological_inventory/satellite/receptor/client/response_worker"

        attr_accessor :default_headers, :logger
        attr_reader :config

        class << self
          def configure
            if block_given?
              yield(Configuration.default)
            else
              Configuration.default
            end
          end
        end
        delegate :start, :stop, :to => :response_worker

        def initialize(config: Configuration.default, logger: ManageIQ::Messaging::NullLogger)
          self.config          = config
          self.default_headers = {}
          self.logger          = logger
          self.response_worker = ResponseWorker.new(config, logger)
        end

        def connection_status(account_number, node_id)
          body     = {
            "account" => account_number,
            "node_id" => node_id
          }.to_json

          response = Faraday.post(config.connection_status_url, body, default_headers)
          # puts "BODY: #{body}, RESPONSE: #{response.body}"
          JSON.parse(response.body)
        end

        def send_directive(account_number, node_id,
                           payload:,
                           directive:,
                           response_object:,
                           response_callback: :response_received,
                           timeout_callback: :response_timeout)
          body = {
            :account   => account_number,
            :recipient => node_id,
            :payload   => payload,
            :directive => directive
          }

          response = Faraday.post(config.job_url, body.to_json, default_headers)
          msg_id   = JSON.parse(response.body)['id']

          # registers message id for kafka responses
          response_worker.register_message(msg_id,
                                           response_object,
                                           :response_callback => response_callback,
                                           :timeout_callback  => timeout_callback)

          msg_id
        end

        private

        attr_writer :config
        attr_accessor :response_worker
      end
    end
  end
end
