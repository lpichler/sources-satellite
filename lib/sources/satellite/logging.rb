require "insights/loggers"

module Sources
  module Satellite
    APP_NAME = "sources-satellite-operations".freeze
    LOGGER_CLASS = "Insights::Loggers::CloudWatch".freeze

    class << self
      attr_writer :logger
    end

    def self.logger
      log_params = {:app_name => APP_NAME, :extend_module => "TopologicalInventory::Providers::Common::LoggingFunctions"}
      @logger ||= Insights::Loggers::Factory.create_logger(LOGGER_CLASS, log_params)
    end

    module Logging
      def logger
        Sources::Satellite.logger
      end
    end
  end
end
