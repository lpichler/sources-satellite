require "topological_inventory/satellite/operations/worker"

RSpec.describe TopologicalInventory::Satellite::Operations::Worker do
  describe "#run" do
    let(:client) { double("ManageIQ::Messaging::Client") }
    let(:receptor_client) { double("TopologicalInventory::Satellite::Receptor::Client") }
    let(:subject) { described_class.new }
    before do
      TopologicalInventory::Satellite::MessagingClient.class_variable_set(:@@default, nil)
      allow(subject).to receive(:client).and_return(client)
      allow(client).to receive(:close)

      allow(TopologicalInventory::Satellite::Receptor::Client).to receive(:new).and_return(receptor_client)
      allow(receptor_client).to receive(:start)
      allow(receptor_client).to receive(:stop)
    end

    it "calls subscribe_topic on the right queue" do
      operations_topic = "platform.topological-inventory.operations-satellite"

      message = double("ManageIQ::Messaging::ReceivedMessage")
      allow(message).to receive(:ack)

      expect(client).to receive(:subscribe_topic)
        .with(hash_including(:service => operations_topic)).and_yield(message)
      expect(TopologicalInventory::Satellite::Operations::Processor)
        .to receive(:process!).with(message, receptor_client)
      subject.run
    end

    it "starts and stops clients" do
      allow(client).to receive(:subscribe_topic)

      expect(receptor_client).to receive(:start)
      expect(receptor_client).to receive(:stop)
      expect(client).to receive(:close)

      subject.run
    end
  end
end
