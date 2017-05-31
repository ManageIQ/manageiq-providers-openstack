if ENV['CI']
  require 'simplecov'
  SimpleCov.start
end

VCR.configure do |config|
  config.ignore_hosts 'codeclimate.com' if ENV['CI']
  config.cassette_library_dir = File.join(ManageIQ::Providers::Openstack::Engine.root, 'spec/vcr_cassettes')
end

Dir[Rails.root.join("spec/shared/**/*.rb")].each { |f| require f }

module EvmSpecHelper
  def self.stub_amqp_support
    require 'manageiq/providers/openstack/legacy/events/openstack_rabbit_event_monitor'
    allow(OpenstackRabbitEventMonitor).to receive(:available?).and_return(true)
    allow(OpenstackRabbitEventMonitor).to receive(:test_connection).and_return(true)
  end
end
