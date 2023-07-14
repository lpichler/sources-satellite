require "sources/satellite/logging"

RSpec.describe Sources::Satellite do
  before do
    Sources::Satellite.class.send(:define_method, :unset_logger) do
      @logger = nil
    end
  end

  it "uses proper logger class" do
    logger = Sources::Satellite.logger
    expect(logger).to be_kind_of(ManageIQ::Loggers::Container)
  end

  after do
    Sources::Satellite.unset_logger
  end
end
