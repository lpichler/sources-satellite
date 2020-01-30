require "manageiq/loggers"

module TopologicalInventory
  module Satellite
    class << self
      attr_writer :logger
    end

    def self.logger
      @logger ||= ManageIQ::Loggers::CloudWatch.new
    end

    module Logging
      def logger
        TopologicalInventory::Satellite.logger
      end
    end
  end
end
