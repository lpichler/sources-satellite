require "topological_inventory/satellite/logging"
require "receptor_controller-client"

module TopologicalInventory
  module Satellite
    class Connection
      class << self
        def connection(account_number)
          new(account_number)
        end
      end

      @sync = Mutex.new
      @receptor_client = nil

      class << self
        # Receptor client needs to be singleton due to processing of kafka responses
        def receptor_client
          @sync.synchronize do
            return @receptor_client if @receptor_client.present?

            @receptor_client = ReceptorController::Client.new(:logger => TopologicalInventory::Satellite.logger)
            @receptor_client.start
          end
          @receptor_client
        end
        alias start_receptor_client receptor_client

        # Stops thread with response worker
        def stop_receptor_client
          @sync.synchronize do
            @receptor_client&.stop
          end
        end
      end

      def initialize(account_number)
        self.account_number = account_number

        receptor_client.identity_header = identity_header
      end

      # This header is used only when ReceptorController::Client::Configuration.pre_shared_key is blank (x-rh-rbac-psk)
      # org_id with any number is required by receptor_client controller
      def identity_header(account = account_number)
        @identity ||= {
          "x-rh-identity" => Base64.strict_encode64(
            {"identity" => {"account_number" => account, "user" => {"is_org_admin" => true}, "internal" => {"org_id" => '000001'}}}.to_json
          )
        }
      end

      def receptor_client
        self.class.receptor_client
      end

      def status(receptor_node_id)
        response = receptor_client.connection_status(account_number, receptor_node_id)
        response['status']
      end

      # @return [String] UUID - message ID for callbacks
      def send_availability_check(source_ref, receptor_node_id, receiver)
        directive = receptor_client.directive(account_number,
                                              receptor_node_id,
                                              :directive => "receptor_satellite:health_check",
                                              :payload   => {'satellite_instance_id' => source_ref.to_s}.to_json,
                                              :type      => :non_blocking)
        directive.on_success { |msg_id, response| receiver.availability_check_response(msg_id, response) }
                 .on_error { |msg_id, code, response| receiver.availability_check_error(msg_id, code, response) }
                 .on_timeout { |msg_id| receiver.availability_check_timeout(msg_id) }
      end

      private

      attr_accessor :account_number
    end
  end
end
