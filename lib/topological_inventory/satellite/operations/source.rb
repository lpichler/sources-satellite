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

        attr_accessor :params, :context, :receptor_worker, :source_id, :source_uid

        def initialize(params = {}, request_context = nil, receptor_worker = nil)
          self.params  = params
          self.context = request_context
          self.receptor_worker = receptor_worker
          self.source_id = nil
          self.source_uid = nil
        end

        def availability_check
          %w[source_id source_uid].each do |attr|
            unless params[attr]
              logger.error("Missing #{attr} for the availability_check request")
              return
            end
            self.send("#{attr}=", params[attr])
          end

          if connection_check(source_id, source_uid) == STATUS_UNAVAILABLE
            update_source(source_id, STATUS_UNAVAILABLE)
          end
        end

        # TODO: update after "satellite:health_check" directive available
        def availability_check_response(_msg_id, data)
          if false
            response = JSON.parse(data)
            # TODO: format of fifi_ready value is not defined yet
            status = response['result'] == 'ok' && response['fifi_ready'].to_i == 1 ? STATUS_AVAILABLE : STATUS_UNAVAILABLE

            if status == STATUS_UNAVAILABLE
             logger.warn("Source #{source_id} is unavailable. Reason: #{response['message']}")
            end

            update_source(source_id, status)
          else
            # woohoo, always successful
            update_source(source_id, STATUS_AVAILABLE)
          end
        end

        private

        def update_source(source_id, status)
          source = SourcesApiClient::Source.new
          source.availability_status = status

          api_client.update_source(source_id, source)
        rescue SourcesApiClient::ApiError => e
          logger.error("Failed to update Source id:#{source_id} - #{e.message}")
        end

        def connection_check(source_id, source_uid)
          endpoint = api_client.list_source_endpoints(source_id)&.data&.detect(&:default)
          return STATUS_UNAVAILABLE unless endpoint

          connection = TopologicalInventory::Satellite::Connection.connection(params["external_tenant"], endpoint.receptor_node)

          if receptor_network_status(connection) == STATUS_AVAILABLE
            endpoint_check(connection, source_uid, endpoint.receptor_node)
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
        def endpoint_check(connection, source_uid, receptor_node_id)
          connection.send_availability_check(self, source_uid, receptor_node_id, receptor_worker)
        end
      end
    end
  end
end
