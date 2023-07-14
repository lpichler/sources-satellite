require "sources/satellite/logging"
require "sources/satellite/connection"
require "sources/satellite/operations/processor"
require "topological_inventory/providers/common/mixins/statuses"
require "topological_inventory/providers/common/operations/health_check"
require "rdkafka"
require "manageiq/messaging/kafka/common"
require "clowder-common-ruby"

module Sources
  module Satellite
    module Operations
      class Worker
        include Logging
        include TopologicalInventory::Providers::Common::Mixins::Statuses

        # hacky hack hack hack :)
        include ManageIQ::Messaging::Kafka::Common

        OPERATIONS_QUEUE_NAME = "platform.topological-inventory.operations-satellite".freeze
        GROUP_ID = "sources-operations-satellite".freeze

        def initialize(metrics)
          self.metrics = metrics
        end

        def run
          start_workers

          logger.info("Sources Satellite Operations worker started...")

          topic = kafka_topic(OPERATIONS_QUEUE_NAME)

          client.subscribe(topic)

          # touch the healthcheck file since we were able to successfully subscribe to the topic
          TopologicalInventory::Providers::Common::Operations::HealthCheck.touch_file

          client.each do |message|
            # calling the private method on the kafka common module :skull:
            self.send(:process_topic_message, client, topic, message) do |parsed|
              process_message(parsed)
            end
          end
        rescue => err
          logger.error("#{err.message}\n#{err.backtrace.join("\n")}")
        ensure
          client&.close
          stop_workers
        end

        private

        attr_accessor :metrics

        def client
          # overriding with raw rdkafka consumer
          @client ||= Rdkafka::Config.new(queue_opts).consumer
        end

        def queue_opts
          # parsing the clowder config file and building the rdkafka args, docs here: https://github.com/edenhill/librdkafka/blob/master/CONFIGURATION.md

          # the default params, overriding what we need to in the tap block...
          {
            :"client.id" => ENV['HOSTNAME'].presence || SecureRandom.hex(4),
            :"group.id" => GROUP_ID,
            :"enable.auto.commit" => true
          }.tap do |params|
            if ClowderCommonRuby::Config.clowder_enabled?
              broker = config.kafka.brokers[0]
              params[:"bootstrap.servers"] = "#{broker.hostname}:#{broker.port}"

              if broker.authtype == "sasl" && broker.respond_to?(:sasl) && broker.sasl.present?
                params[:"sasl.username"] = broker.sasl.username
                params[:"sasl.password"] = broker.sasl.password
                params[:"sasl.mechanism"] = broker.sasl.saslMechanism
                params[:"security.protocol"] = broker.sasl.securityProtocol
                params[:"ssl.certificate.pem"] = broker.cacert if broker.respond_to?(:cacert) && broker.cacert.present?
              end
            else
              params[:"bootstrap.servers"] = "#{ENV["QUEUE_HOST"]}:#{ENV["QUEUE_PORT"]}"
            end
          end
        end

        def process_message(message)
          result = Processor.process!(message, metrics)
          metrics&.record_operation(message.message, :status => result) unless result.nil?
        rescue => e
          logger.error("#{e}\n#{e.backtrace.join("\n")}")
          metrics&.record_operation(message.message, :status => operation_status[:error])
        ensure
          TopologicalInventory::Providers::Common::Operations::HealthCheck.touch_file
        end

        def start_workers
          Sources::Satellite::Connection.start_receptor_client
        end

        def stop_workers
          Sources::Satellite::Connection.stop_receptor_client
        end

        def config
          @config ||= ClowderCommonRuby::Config.load if ClowderCommonRuby::Config.clowder_enabled?
        end

        def kafka_topic(name)
          if ClowderCommonRuby::Config.clowder_enabled?
            config.kafka.topics.find {|t| t.requestedName == name}&.name || name
          else
            name
          end
        end
      end
    end
  end
end
