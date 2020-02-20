require "manageiq-messaging"

module TopologicalInventory::Satellite
  module Receptor
    class ResponseWorker
      include Logging

      attr_reader :started
      alias_method :started?, :started

      def initialize(queue_host, queue_port)
        self.started = false
        self.queue_host = queue_host
        self.queue_port = queue_port
        self.registered_messages = Concurrent::Map.new
      end

      def start
        return if started

        self.started = true
        Thread.new { listen }
      end

      def register_msg_id(msg_id, api_object, response_method = :response_received)
        registered_messages[msg_id] = { :api_object => api_object, :method => response_method }
      end

      private

      attr_accessor :queue_host, :queue_port, :registered_messages
      attr_writer :started

      def listen
        # Open a connection to the messaging service
        client = ManageIQ::Messaging::Client.open(default_messaging_opts)

        logger.info("Receptor Response worker started...")
        client.subscribe_topic(queue_opts) do |message|
          process_message(message)
        end
      ensure
        client&.close
      end

      def process_message(message)
        response = JSON.parse(message.payload)
        if response['code'] == 0
          message_id = response['in_response_to']
          # message_type: "response" (with data) or
          #               "eof"(without data)
          message_type = response['message_type']

          if message_id
            if (callback = registered_messages[message_id]).present?
              registered_messages.delete(message_id) if message_type == 'eof'
              # Callback to sender
              callback[:api_object].send(callback[:method], message_id, message_type, response['payload'])
            else
              logger.warn("Received Unknown Receptor Message ID (#{message_id}): #{response.inspect}")
            end
          else
            raise "Message id (in_response_to) not received! #{response}"
          end
        else
          logger.error("Receptor_satellite:health_check directive failed in receptor node #{response['sender']}")
        end
      rescue JSON::ParserError => e
        logger.error("Failed to parse Kafka response (#{e.message})\n#{message.payload}")
      rescue StandardError => e
        logger.error("#{e}\n#{e.backtrace.join("\n")}")
      end

      def queue_name
        "platform.receptor-controller.responses"
      end

      def queue_opts
        {
          # :max_bytes   => 50_000,
          :service     => queue_name,
          :persist_ref => "topological-inventory-receptor-responses"
        }
      end

      def default_messaging_opts
        {
          :host       => queue_host,
          :port       => queue_port,
          :protocol   => :Kafka,
          :client_ref => "topological-inventory-receptor-responses",
          :group_ref  => "topological-inventory-receptor-responses"
        }
      end
    end
  end
end