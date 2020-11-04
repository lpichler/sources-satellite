require "manageiq-messaging"
require "topological_inventory/satellite/logging"
require "topological_inventory/satellite/messaging_client"
require "topological_inventory/satellite/receptor/client"
require "topological_inventory/satellite/operations/processor"
require "topological_inventory/satellite/operations/source"
require "topological_inventory/providers/common/operations/health_check"

module TopologicalInventory
  module Satellite
    module Operations
      class Worker
        include Logging

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

        def client
          @client ||= TopologicalInventory::Satellite::MessagingClient.default.worker_listener
        end

        def queue_opts
          TopologicalInventory::Satellite::MessagingClient.default.worker_listener_queue_opts
        end

        def process_message(message, receptor_client)
          Processor.process!(message, receptor_client)
        rescue => e
          logger.error("#{e}\n#{e.backtrace.join("\n")}")
          raise
        ensure
          message.ack
          TopologicalInventory::Providers::Common::Operations::HealthCheck.touch_file
        end
      end
    end
  end
end
