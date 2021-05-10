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

  context "" do
    before do
      ENV['LOG_HANDLER'] = "haberdasher"
    end
    it "uses proper logger class" do
      require "manageiq/loggers/base"
      require "manageiq/loggers/container"
      require "insights/loggers"
      require "insights/loggers/std_error_logger"

      logger = Sources::Satellite.logger
      expect(logger).to be_kind_of(Insights::Loggers::StdErrorLogger)
      expect(logger).to respond_to(:availability_check)
    end

    after do
      Sources::Satellite.unset_logger
    end
  end
end
