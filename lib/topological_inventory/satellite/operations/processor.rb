require "topological_inventory/satellite/logging"
require "topological_inventory/satellite/operations/source"
require "topological_inventory/providers/common/operations/processor"

module TopologicalInventory
  module Satellite
    module Operations
      class Processor < TopologicalInventory::Providers::Common::Operations::Processor
        include Logging

        def operation_class
          "#{Operations}::#{model}".safe_constantize
        end
      end
    end
  end
end
