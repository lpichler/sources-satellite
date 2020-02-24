require "sources-api-client"
require "active_support/core_ext/numeric/time"
require "topological_inventory/satellite/connection"
require "topological_inventory/satellite/operations/core/authentication_retriever"
require "topological_inventory/satellite/logging"

module TopologicalInventory
  module Satellite
    module Operations
      class Source
        include Logging
        STATUS_AVAILABLE, STATUS_UNAVAILABLE = %w[available unavailable].freeze

        attr_accessor :source_id, :source_uid

        def initialize(params = {}, request_context = nil, receptor_client = nil)
          self.params          = params
          self.request_context = request_context
          self.connection      = TopologicalInventory::Satellite::Connection.connection(params["external_tenant"], receptor_client)
          self.source_id       = params['source_id']
          self.source_uid      = params['source_uid']
        end

        # Entrypoint for "Source:availability_check" operation
        #
        # It updates Source only when unavailable, otherwise it waits
        # for asynchronous #availability_check_[response|timeout]
        def availability_check
          return if params_missing?

          unless available?(connection_status)
            update_source(STATUS_UNAVAILABLE)
          end
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

          unless available?(status)
            logger.info("Source #{source_id} is unavailable. Result: #{response['result']}, FIFI status: #{response['fifi_status'] ? 'T' : 'F'}, Reason: #{response['message']}")
          end

          update_source(status)
        end

        # Timeout callback from receptor client
        #
        # Kafka message wan't delivered for unknown reason
        #
        # @param msg_id [String] UUID of request's id
        def availability_check_timeout(msg_id)
          logger.error("Receptor doesn't respond for Source (ID #{source_id}) | (message id: #{msg_id})")
          update_source(STATUS_UNAVAILABLE)
        end

        private

        attr_accessor :connection, :params, :request_context

        def available?(status)
          status.to_s == STATUS_AVAILABLE
        end

        def params_missing?
          is_missing = false
          %w[source_id source_uid].each do |attr|
            if (is_missing = params[attr].blank?)
              logger.error("Missing #{attr} for the availability_check request")
              break
            end
          end

          is_missing
        end

        def update_source(status)
          source = SourcesApiClient::Source.new
          source.availability_status = status

          api_client.update_source(source_id, source)
        rescue SourcesApiClient::ApiError => e
          logger.error("Failed to update Source id:#{source_id} - #{e.message}")
        end

        def connection_status
          endpoint = api_client.list_source_endpoints(source_id)&.data&.detect(&:default)
          return STATUS_UNAVAILABLE unless endpoint

          if available?(receptor_network_status(endpoint.receptor_node))
            if send_availability_check(endpoint.receptor_node)
              return STATUS_AVAILABLE
            end
          end

          STATUS_UNAVAILABLE
        rescue => e
          logger.error("Failed to connect to Source id:#{source_id} - #{e.message}")
          STATUS_UNAVAILABLE
        end

        def api_client
          @api_client ||= begin
            api_client = SourcesApiClient::ApiClient.new
            api_client.default_headers.merge!(connection.identity_header)
            SourcesApiClient::DefaultApi.new(api_client)
          end
        end

        def receptor_network_status(receptor_node_id)
          connection.status(receptor_node_id) == "connected" ? STATUS_AVAILABLE : STATUS_UNAVAILABLE
        end

        # @return [String|nil] UUID - message ID for callbacks
        def send_availability_check(receptor_node_id)
          connection.send_availability_check(source_uid, receptor_node_id, self)
        end
      end
    end
  end
end
