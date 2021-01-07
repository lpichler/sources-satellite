require "sources-api-client"
require "topological_inventory/satellite/operations/source"

RSpec.describe TopologicalInventory::Satellite::Operations::Source do
  let(:host_url) { "https://cloud.redhat.com" }
  let(:external_tenant) { "11001" }
  let(:identity) do
    { "x-rh-identity" => Base64.strict_encode64({ "identity" => { "account_number" => external_tenant, "user" => { "is_org_admin" => true } } }.to_json) }
  end
  let(:headers) { {"Content-Type" => "application/json"}.merge(identity) }
  let(:connection) { double("TopologicalInventory::Satellite::Connection") }
  let(:metrics) { double("Metrics", :record_operation => nil) }

  before do
    allow(TopologicalInventory::Satellite::Connection).to receive(:connection).and_return(connection)
    allow(connection).to receive(:identity_header).and_return(identity)
  end

  describe "#update_source" do
    let(:availability_status) { described_class::STATUS_AVAILABLE }
    let(:source_id) { '201' }
    let(:payload) { {"params" => {"source_id" => source_id, "external_tenant" => external_tenant, "timestamp" => Time.now.utc}} }

    context "via sources_api" do
      around do |example|
        ENV['UPDATE_SOURCES_VIA_API'] = 'true'
        example.run
        ENV['UPDATE_SOURCES_VIA_API'] = nil
      end

      it "makes a patch request to update the availability_status of a source" do
        checker = described_class.new(payload["params"])

        stub_request(:get, "https://cloud.redhat.com/api/sources/v3.0/sources/#{source_id}/endpoints")
          .with(:headers => headers)
          .to_return(:status => 200, :body => "", :headers => {})
        stub_request(:get, "https://cloud.redhat.com/api/sources/v3.0/sources/#{source_id}/applications")
          .with(:headers => headers)
          .to_return(:status => 200, :body => "", :headers => {})
        stub_request(:patch, "https://cloud.redhat.com/api/sources/v3.0/sources/#{source_id}")
          .with(:body => {"availability_status" => availability_status, 'last_available_at' => checker.send(:check_time), 'last_checked_at' => checker.send(:check_time)}.to_json, :headers => headers)
          .to_return(:status => 200, :body => "", :headers => {})

        checker.send(:update_source_and_subresources, availability_status)
      end
    end

    context "via kafka" do
      it "makes a patch request to update the availability_status of a source" do
        expect(TopologicalInventory::Providers::Common::MessagingClient.default.client).to receive(:publish_topic).with(
          {
            :event   => "availability_status",
            :payload => "{\"resource_type\":\"Source\",\"resource_id\":\"201\",\"status\":\"available\"}",
            :service => "platform.sources.status",
            :headers => {"x-rh-identity" => "eyJpZGVudGl0eSI6eyJhY2NvdW50X251bWJlciI6IjExMDAxIiwidXNlciI6eyJpc19vcmdfYWRtaW4iOnRydWV9fX0="}
          }
        )

        stub_request(:get, "https://cloud.redhat.com/api/sources/v3.0/sources/#{source_id}/endpoints")
          .with(:headers => headers)
          .to_return(:status => 200, :body => "", :headers => {})
        stub_request(:get, "https://cloud.redhat.com/api/sources/v3.0/sources/#{source_id}/applications")
          .with(:headers => headers)
          .to_return(:status => 200, :body => "", :headers => {})

        described_class.new(payload["params"]).send(:update_source_and_subresources, availability_status)
      end
    end
  end

  describe "#availability_check" do
    let(:params) { {'source_id' => '1', 'source_uid' => '1234-5678', 'source_ref' => '9101112-13141516'} }

    subject { described_class.new(params, nil, metrics) }
    before { allow(subject).to receive(:checked_recently?).and_return(false) }

    context "with missing params" do
      let(:params) { {} }

      it "doesn't update the Source if params missing" do
        expect(subject).not_to receive(:connection_status)
        expect(subject).not_to receive(:update_source_and_subresources)

        expect(subject.send(:availability_check)).to eq(subject.operation_status[:error])
      end
    end

    it "updates the Sources's status if Source is unavailable" do
      expect(subject).to receive(:connection_status).and_return(described_class::STATUS_UNAVAILABLE)
      expect(subject).to receive(:update_source_and_subresources)

      expect(subject.send(:availability_check)).to be_nil
    end
  end

  describe "#availability_check_response" do
    subject { described_class.new({}, nil, metrics) }
    before do
      allow(subject).to receive(:checked_recently?).and_return(false)
      subject.operation = "Source#availability_check"
    end

    it "does nothing if 'eof' message received" do
      expect(subject).not_to receive(:update_source_and_subresources)
      expect(metrics).not_to receive(:record_operation)

      subject.send(:availability_check_response, '1', 'eof', nil)
    end

    it "updates Source to 'available' if response successes" do
      response = {
        'result'      => 'ok',
        'fifi_status' => true,
        'message' => 'Satellite online and ready'
      }

      expect(subject).to receive(:update_source_and_subresources).with(described_class::STATUS_AVAILABLE, response['message'])
      expect(metrics).to receive(:record_operation).with('Source.availability_check', :status => subject.operation_status[:success])

      subject.send(:availability_check_response, nil, 'response', response)
    end

    it "updates Source to 'unavailable' if response not ok" do
      response = {
        'result'      => 'error',
        'fifi_status' => true,
        'message'     => 'Satellite NOT READY'
      }

      expect(subject).to receive(:update_source_and_subresources).with(described_class::STATUS_UNAVAILABLE, response['message'])
      expect(metrics).to receive(:record_operation).with('Source.availability_check', :status => subject.operation_status[:success])

      subject.send(:availability_check_response, nil, 'response', response)
    end

    it "updates Source to 'unavailable' if Satellite not ready for FIFI" do
      response = {
        'result'      => 'ok',
        'fifi_status' => false,
        'message'     => 'Satellite online but FIFI not ready'
      }

      expect(subject).to receive(:update_source_and_subresources).with(described_class::STATUS_UNAVAILABLE, response['message'])
      expect(metrics).to receive(:record_operation).with('Source.availability_check', :status => subject.operation_status[:success])

      subject.send(:availability_check_response, nil, 'response', response)
    end
  end

  describe "#availability_check_timeout" do
    subject { described_class.new({}, nil, metrics) }
    before do
      allow(subject).to receive(:checked_recently?).and_return(false)
      subject.operation = "Source#availability_check"
    end

    it "updates Source to 'unavailable'" do
      expect(subject).to receive(:update_source_and_subresources).with(described_class::STATUS_UNAVAILABLE, described_class::ERROR_MESSAGES[:receptor_not_responding])
      expect(metrics).to receive(:record_operation).with('Source.availability_check', :status => subject.operation_status[:error])

      subject.send(:availability_check_timeout, '1')
    end
  end
end
