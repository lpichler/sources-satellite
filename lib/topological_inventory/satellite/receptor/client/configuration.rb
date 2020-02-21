module TopologicalInventory
  module Satellite
    module Receptor
      class Client::Configuration
        attr_accessor :controller_scheme
        attr_accessor :controller_host

        attr_accessor :connection_status_path
        attr_accessor :job_path

        attr_accessor :kafka_response_topic

        attr_accessor :queue_host
        attr_accessor :queue_port

        def initialize
          @controller_scheme = 'http'
          @controller_host   = 'localhost:9090'

          @connection_status_path = '/connection/status'
          @job_path               = '/job'

          @kafka_response_topic = 'platform.receptor-controller.responses'

          @queue_host, @queue_port = nil, nil

          yield(self) if block_given?
        end

        def self.default
          @@default ||= self.new
        end

        def configure
          yield(self) if block_given?
        end

        def scheme=(scheme)
          # remove :// from scheme
          @scheme = scheme.sub(/:\/\//, '')
        end

        def host=(host)
          # remove http(s):// and anything after a slash
          @host = host.sub(/https?:\/\//, '').split('/').first
        end

        def controller_url
          "#{controller_scheme}://#{controller_host}".sub(/\/+\z/, '')
        end

        def connection_status_url
          File.join(controller_url, connection_status_path)
        end

        def job_url
          File.join(controller_url, job_path)
        end
      end
    end
  end
end
