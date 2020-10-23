require "manageiq-messaging"
require "topological_inventory/satellite/logging"
require "topological_inventory/satellite/messaging_client"
require "topological_inventory/satellite/receptor/client"
require "topological_inventory/satellite/operations/processor"
require "topological_inventory/providers/common/mixins/statuses"
require "topological_inventory/providers/common/operations/health_check"

module TopologicalInventory
  module Satellite
    module Operations
      class Worker
        include Logging
        include TopologicalInventory::Providers::Common::Mixins::Statuses

        def initialize(metrics)
          self.metrics = metrics
        end

        def run
          receptor_client = TopologicalInventory::Satellite::Receptor::Client.new(:logger => logger)
          receptor_client.start

          logger.info("Topological Inventory Satellite Operations worker started...")

          client.subscribe_topic(queue_opts) do |message|
            process_message(message, receptor_client)
          end
        ensure
          client&.close
          receptor_client&.stop
        end

        private

        attr_accessor :metrics

        def client
          @client ||= TopologicalInventory::Satellite::MessagingClient.default.worker_listener
        end

        def queue_opts
          TopologicalInventory::Satellite::MessagingClient.default.worker_listener_queue_opts
        end

        def process_message(message, receptor_client)
          result = Processor.process!(message, metrics, receptor_client)
          metrics&.record_operation(message.message, :status => result) unless result.nil?
        rescue => e
          logger.error("#{e}\n#{e.backtrace.join("\n")}")
          metrics&.record_operation(message.message, :status => operation_status[:error])
        ensure
          message.ack
          TopologicalInventory::Providers::Common::Operations::HealthCheck.touch_file
        end
      end
    end
  end
end
