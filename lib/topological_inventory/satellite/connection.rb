module TopologicalInventory
  module Satellite
    module Connection
      class << self
        def connection(options = {})
          raw_connect(options)
        end

        private

        def raw_connect()
        end
      end
    end
  end
end
