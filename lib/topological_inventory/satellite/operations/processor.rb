require "topological_inventory/satellite/logging"
require "topological_inventory/satellite/operations/source"
require "topological_inventory/providers/common/operations/processor"

module TopologicalInventory
  module Satellite
    module Operations
      class Processor < TopologicalInventory::Providers::Common::Operations::Processor
        include Logging

        # def self.process!(message, metrics, receptor_client)
        #   new(message, metrics, receptor_client).process
        # end
        #
        # def initialize(message, metrics, receptor_client)
        #   super(message, metrics)
        #   self.receptor_client = receptor_client
        # end
        #
        # def process
        #   logger.info(status_log_msg)
        #   impl = operation_class&.new(params, identity, metrics, receptor_client)
        #   if impl&.respond_to?(method)
        #     with_time_measure do
        #       result = impl.send(method)
        #
        #       logger.info(status_log_msg("Complete"))
        #       result
        #     end
        #   else
        #     logger.warn(status_log_msg("Not Implemented!"))
        #     complete_task("not implemented") if params["task_id"]
        #     operation_status[:not_implemented]
        #   end
        # rescue StandardError, NotImplementedError => e
        #   complete_task(e.message) if params["task_id"]
        #   raise
        # end
        #
        # private
        #
        # attr_accessor :receptor_client

        def operation_class
          "#{Operations}::#{model}".safe_constantize
        end
      end
    end
  end
end
