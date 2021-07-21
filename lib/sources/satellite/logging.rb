require "insights/loggers"

module Sources
  module Satellite
    APP_NAME = "sources-satellite-operations".freeze

    class << self
      attr_writer :logger
    end

    def self.logger_class
      if ENV['LOG_HANDLER'] == "haberdasher"
        "Insights::Loggers::StdErrorLogger"
      else
        "Insights::Loggers::CloudWatch"
      end
    end

    def self.logger
      log_params = {:app_name => APP_NAME, :extend_module => "TopologicalInventory::Providers::Common::LoggingFunctions"}
      @logger ||= Insights::Loggers::Factory.create_logger(logger_class, log_params)
    end

    module Logging
      def logger
        Sources::Satellite.logger
      end
    end
  end
end
