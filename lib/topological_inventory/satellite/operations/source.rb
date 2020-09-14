require "topological_inventory/satellite/connection"
require "topological_inventory/satellite/logging"
require "topological_inventory/providers/common/operations/source"

module TopologicalInventory
  module Satellite
    module Operations
      class Source < TopologicalInventory::Providers::Common::Operations::Source
        include Logging

        ERROR_MESSAGES = {
          :endpoint_not_found           => "Endpoint not found in Sources API",
          :receptor_network_unreachable => "Receptor network unreachable",
          :receptor_node_disconnected   => "Receptor node is disconnected",
          :receptor_node_not_defined    => "Receptor node not defined in Sources API",
          :receptor_not_responding      => "Receptor is not responding",
        }.freeze

        attr_accessor :source_id, :source_uid, :source_ref

        def initialize(params = {}, request_context = nil, receptor_client = nil)
          super(params, request_context)
          self.connection      = TopologicalInventory::Satellite::Connection.connection(params["external_tenant"], receptor_client)
          self.source_uid      = params['source_uid']
          self.source_ref      = params['source_ref']
        end

        # Response callback from receptor client
        #
        # Health check returns maximally one message of type "response"
        #
        # @param _msg_id [String] UUID of request's id
        # @param message_type [String] "response" | "eof"
        # @param response [Hash]
        def availability_check_response(_msg_id, message_type, response)
          return if message_type == 'eof' # noop

          connected = response['result'] == 'ok' && response['fifi_status']
          status = connected ? STATUS_AVAILABLE : STATUS_UNAVAILABLE

          logger.info("Source#availability_check for source #{source_id} completed. Status: #{status}, Result: #{response['result']}, FIFI status: #{response['fifi_status'] ? 'T' : 'F'}, Reason: #{response['message']}")
          update_source_and_subresources(status, response['message'])
        end

        # Timeout callback from receptor client
        #
        # Kafka message wan't delivered for unknown reason
        #
        # @param msg_id [String] UUID of request's id
        def availability_check_timeout(msg_id)
          logger.error("Source#availability_check - Receptor doesn't respond for Source (ID #{source_id}) | (message id: #{msg_id})")
          update_source_and_subresources(STATUS_UNAVAILABLE, ERROR_MESSAGES[:receptor_not_responding])
        end

        private

        attr_accessor :connection, :params, :request_context

        def available?(status)
          status.to_s == STATUS_AVAILABLE
        end

        def connection_check
          status, msg = STATUS_UNAVAILABLE, nil

          if available?(receptor_network_status(endpoint.receptor_node))
            if send_availability_check(endpoint.receptor_node)
              status = STATUS_AVAILABLE
            else
              msg = ERROR_MESSAGES[:receptor_network_unreachable]
            end
          else
            msg = ERROR_MESSAGES[:receptor_node_disconnected]
          end

          [status, msg]
        rescue => e
          logger.error("Source#availability_check - Failed to connect to Source id:#{source_id} - #{e.message}")
          [STATUS_UNAVAILABLE, e.message]
        end

        def receptor_network_status(receptor_node_id)
          connection.status(receptor_node_id) == "connected" ? STATUS_AVAILABLE : STATUS_UNAVAILABLE
        end

        # @return [String|nil] UUID - message ID for callbacks
        def send_availability_check(receptor_node_id)
          connection.send_availability_check(source_ref, receptor_node_id, self)
        end
      end
    end
  end
end
