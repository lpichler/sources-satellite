require "topological_inventory/satellite/logging"
require "topological_inventory/satellite/operations/processor"
require "topological_inventory/satellite/receptor/response_worker"
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
          # Run receptor response listener
          receptor_worker = Receptor::ResponseWorker.new(messaging_client_opts[:host], messaging_client_opts[:port])
          receptor_listener = receptor_worker.start

          # Open a connection to the messaging service
          require "manageiq-messaging"
          client = ManageIQ::Messaging::Client.open(messaging_client_opts)

          logger.info("Topological Inventory Satellite Operations worker started...")
          client.subscribe_topic(queue_opts) do |message|
            process_message(message, receptor_worker)
          end

        ensure
          client&.close
          receptor_listener&.kill
        end

        private

        attr_accessor :messaging_client_opts

        def process_message(message, receptor_worker)
          Processor.process!(message, receptor_worker)
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
