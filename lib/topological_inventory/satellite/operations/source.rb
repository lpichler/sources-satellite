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

        attr_accessor :params, :context, :source_id

        def initialize(params = {}, request_context = nil)
          @params  = params
          @context = request_context
          @source_id = nil
        end

        def availability_check
          source_id = params["source_id"]
          unless source_id
            logger.error("Missing source_id for the availability_check request")
            return
          end

          source = SourcesApiClient::Source.new
          source.availability_status = connection_check(source_id)

          begin
            api_client.update_source(source_id, source)
          rescue SourcesApiClient::ApiError => e
            logger.error("Failed to update Source id:#{source_id} - #{e.message}")
          end
        end

        private

        def connection_check(source_id)
          endpoint = api_client.list_source_endpoints(source_id)&.data&.detect(&:default)
          return STATUS_UNAVAILABLE unless endpoint

          connection = TopologicalInventory::Satellite::Connection.connection(params["external_tenant"], endpoint.receptor_node)
          connection.status == "connected" ? STATUS_AVAILABLE : STATUS_UNAVAILABLE
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
      end
    end
  end
end
