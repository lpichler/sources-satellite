require "sources/satellite/logging"
require "sources/satellite/connection"
require "sources/satellite/messaging_client"
require "sources/satellite/operations/processor"
require "topological_inventory/providers/common/mixins/statuses"
require "topological_inventory/providers/common/operations/health_check"

module Sources
  module Satellite
    module Operations
      class Worker
        include Logging
        include TopologicalInventory::Providers::Common::Mixins::Statuses

        def initialize(metrics)
          self.metrics = metrics
        end

        def run
          start_workers

          logger.info("Sources Satellite Operations worker started...")
          logger.warn("Sources Satellite Operations worker started...")
          logger.error("Sources Satellite Operations worker started...")

          client.subscribe_topic(queue_opts) do |message|
            process_message(message)
          end
        rescue => err
          logger.error("#{err.message}\n#{err.backtrace.join("\n")}")
        ensure
          client&.close
          stop_workers
        end

        private

        attr_accessor :metrics

        def client
          @client ||= Sources::Satellite::MessagingClient.default.worker_listener
        end

        def queue_opts
          Sources::Satellite::MessagingClient.default.worker_listener_queue_opts
        end

        def process_message(message)
          result = Processor.process!(message, metrics)
          metrics&.record_operation(message.message, :status => result) unless result.nil?
        rescue => e
          logger.error("#{e}\n#{e.backtrace.join("\n")}")
          metrics&.record_operation(message.message, :status => operation_status[:error])
        ensure
          TopologicalInventory::Providers::Common::Operations::HealthCheck.touch_file
        end

        def start_workers
          Sources::Satellite::Connection.start_receptor_client
        end

        def stop_workers
          Sources::Satellite::Connection.stop_receptor_client
        end
      end
    end
  end
end
