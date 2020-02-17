require "sources-api-client"
require "active_support/core_ext/numeric/time"
require "topological_inventory/satellite/connection"
require "topological_inventory/satellite/operations/core/authentication_retriever"

module TopologicalInventory
  module Satellite
    module Operations
      class Source
        include Logging
        STATUS_AVAILABLE, STATUS_UNAVAILABLE = %w[available unavailable].freeze
        RECEPTOR_DIRECTIVE = "receptor:ping".freeze # TODO: this is a test!

        attr_accessor :params, :context, :receptor_worker, :source_id

        def initialize(params = {}, request_context = nil, receptor_worker = nil)
          self.params  = params
          self.context = request_context
          self.receptor_worker = receptor_worker
          self.source_id = nil
        end

        def availability_check
          self.source_id = params["source_id"]
          unless source_id
            logger.error("Missing source_id for the availability_check request")
            return
          end

          if connection_check(source_id) == STATUS_UNAVAILABLE
            update_source(source_id, source)
          end
        end

        # TODO: update after "satellite:ping" directive available
        def availability_check_response(_msg_id)
          # woohoo, always successful
          update_source(source_id, STATUS_AVAILABLE)
        end

        private

        def update_source(source_id, status)
          source = SourcesApiClient::Source.new
          source.availability_status = status

          api_client.update_source(source_id, source)
        rescue SourcesApiClient::ApiError => e
          logger.error("Failed to update Source id:#{source_id} - #{e.message}")
        end

        def connection_check(source_id)
          endpoint = api_client.list_source_endpoints(source_id)&.data&.detect(&:default)
          return STATUS_UNAVAILABLE unless endpoint

          connection = TopologicalInventory::Satellite::Connection.connection(params["external_tenant"], endpoint.receptor_node)

          if receptor_network_status(connection) == STATUS_AVAILABLE
            endpoint_check(connection, endpoint.receptor_node)
            STATUS_AVAILABLE
          else
            STATUS_UNAVAILABLE
          end
        rescue => e
          logger.error("Failed to connect to Source id:#{source_id} - #{e.message}")
          STATUS_UNAVAILABLE
        end

        def identity
          @identity ||= { "x-rh-identity" => Base64.strict_encode64({ "identity" => { "account_number" => params["external_tenant"], "user" => { "is_org_admin" => true }}}.to_json) }
        end

        def api_client
          @api_client ||= begin
            api_client = SourcesApiClient::ApiClient.new
            api_client.default_headers.merge!(identity)
            SourcesApiClient::DefaultApi.new(api_client)
          end
        end

        def receptor_network_status(connection)
          connection.status == "connected" ? STATUS_AVAILABLE : STATUS_UNAVAILABLE
        end

        # Async, it doesn't return value
        def endpoint_check(connection, receptor_node_id)
          connection.send_availability_check(self, receptor_node_id, receptor_worker)
        end
      end
    end
  end
end
