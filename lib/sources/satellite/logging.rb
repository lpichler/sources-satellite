require "topological_inventory/providers/common/logging"

module Sources
  module Satellite
    class << self
      attr_writer :logger
    end

    def self.logger
      @logger ||= TopologicalInventory::Providers::Common::Logger.new
    end

    module Logging
      def logger
        Sources::Satellite.logger
      end
    end
  end
end
