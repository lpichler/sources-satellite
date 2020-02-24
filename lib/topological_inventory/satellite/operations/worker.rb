require "manageiq-messaging"
require "topological_inventory/satellite/logging"
require "topological_inventory/satellite/receptor/client"
require "topological_inventory/satellite/operations/processor"
require "topological_inventory/satellite/operations/source"

module TopologicalInventory
  module Satellite
    module Operations
      class Worker
        include Logging

        def initialize(messaging_client_opts = {})
          self.messaging_client_opts = default_messaging_opts.merge(messaging_client_opts)
        end

        def run
          receptor_client = TopologicalInventory::Satellite::Receptor::Client.new(:logger => logger)
          receptor_client.start

          # Open a connection to the messaging service
          client = ManageIQ::Messaging::Client.open(messaging_client_opts)

          logger.info("Topological Inventory Satellite Operations worker started...")
          client.subscribe_topic(queue_opts) do |message|
            process_message(message, receptor_client)
          end
        ensure
          client&.close
          receptor_client&.stop
        end

        private

        attr_accessor :messaging_client_opts

        def process_message(message, receptor_client)
          Processor.process!(message, receptor_client)
        rescue => e
          logger.error("#{e}\n#{e.backtrace.join("\n")}")
          raise
        ensure
          message.ack
        end

        def queue_name
          "platform.topological-inventory.operations-satellite"
        end

        def queue_opts
          {
            :auto_ack    => false,
            :max_bytes   => 50_000,
            :service     => queue_name,
            :persist_ref => "topological-inventory-operations-satellite"
          }
        end

        def default_messaging_opts
          {
            :protocol   => :Kafka,
            :client_ref => "topological-inventory-operations-satellite",
            :group_ref  => "topological-inventory-operations-satellite"
          }
        end
      end
    end
  end
end
