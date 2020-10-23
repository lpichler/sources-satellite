require "topological_inventory/satellite/operations/worker"

RSpec.describe TopologicalInventory::Satellite::Operations::Worker do
  describe "#run" do
    let(:client) { double("ManageIQ::Messaging::Client") }
    let(:receptor_client) { double("TopologicalInventory::Satellite::Receptor::Client") }
    let(:message) { double("ManageIQ::Messaging::ReceivedMessage") }
    let(:metrics) { double("Metrics", :record_operation => nil) }
    let(:operation) { 'Test.operation' }
    let(:subject) { described_class.new(metrics) }

    before do
      TopologicalInventory::Satellite::MessagingClient.class_variable_set(:@@default, nil)
      allow(subject).to receive(:client).and_return(client)
      allow(client).to receive(:close)

      allow(TopologicalInventory::Providers::Common::Operations::HealthCheck).to receive(:touch_file)
      allow(message).to receive_messages(:ack => nil, :message => operation)

      allow(TopologicalInventory::Satellite::Receptor::Client).to receive(:new).and_return(receptor_client)
      allow(receptor_client).to receive(:start)
      allow(receptor_client).to receive(:stop)
    end

    it "calls subscribe_topic on the right queue" do
      operations_topic = "platform.topological-inventory.operations-satellite"

      expect(client).to receive(:subscribe_topic)
        .with(hash_including(:service => operations_topic)).and_yield(message)
      expect(TopologicalInventory::Satellite::Operations::Processor)
        .to receive(:process!).with(message, metrics, receptor_client)
      subject.run
    end

    it "starts and stops clients" do
      allow(client).to receive(:subscribe_topic)

      expect(receptor_client).to receive(:start)
      expect(receptor_client).to receive(:stop)
      expect(client).to receive(:close)

      subject.run
    end

    context ".metrics" do
      it "records successful operation" do
        result = subject.operation_status[:success]

        allow(TopologicalInventory::Satellite::Operations::Processor).to receive(:process!).and_return(result)
        expect(metrics).to receive(:record_operation).with(operation, :status => result)

        subject.send(:process_message, message, receptor_client)
      end

      it "records exception" do
        result = subject.operation_status[:error]

        allow(TopologicalInventory::Satellite::Operations::Processor).to receive(:process!).and_raise("Test Exception!")
        expect(metrics).to receive(:record_operation).with(operation, :status => result)

        subject.send(:process_message, message, receptor_client)
      end

      it "doesn't record metric if result is nil" do
        result = nil

        allow(TopologicalInventory::Satellite::Operations::Processor).to receive(:process!).and_return(result)
        expect(metrics).not_to receive(:record_operation)

        subject.send(:process_message, message, receptor_client)
      end
    end
  end
end
