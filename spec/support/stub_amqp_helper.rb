module EvmSpecHelper
  def self.stub_amqp_support
    require 'manageiq/providers/openstack/legacy/events/openstack_rabbit_event_monitor'
    allow(OpenstackRabbitEventMonitor).to receive(:available?).and_return(true)
    allow(OpenstackRabbitEventMonitor).to receive(:test_connection).and_return(true)
  end
end
