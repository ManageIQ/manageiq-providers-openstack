require 'manageiq/providers/openstack/legacy/events/openstack_stf_event_monitor'
require 'qpid_proton'

describe OpenstackStfEventMonitor do
  let(:qdr_options) { {:hostname => "machine.local", :port => '5666', :security_protocol => 'non-ssl'} }
  let(:qdr_ssl_options) { {:hostname => "machine.local", :port => '5672', :security_protocol => 'ssl'} }

  context "connecting to STF service" do
    describe "URL prepare" do
      it 'QDR endpoint' do
        expect(subject.class.build_qdr_client_url(qdr_options)).to eq "amqp://machine.local:5666"
      end
  
      it 'QDR SSL endpoint' do
        expect(subject.class.build_qdr_client_url(qdr_ssl_options)).to eq "amqps://machine.local:5672"
      end
    end

    describe 'availability check' do
      it 'test availability success' do
        allow_any_instance_of(Qpid::Proton::Container).to \
          receive(:run).and_return(true)
    #    allow(qdr_connection).to receive(:open_receiver).with("anycast/ceilometer/event.sample").and_return(true)
    #    expect(qdr_connection).to receive(:close)
        expect(subject.class.available?(qdr_options)).to be true
      end
  
      it 'test availability failed' do
        allow_any_instance_of(Qpid::Proton::Container).to \
          receive(:run).and_raise(Qpid::Proton::ProtonError)
        expect(subject.class.available?).to be false
      end
    end
  end

  context "collecting events" do
    describe 'parse' do
      it "unserializes received event" do
        event = subject.unserialize_event("{\"request\": {\"oslo.version\": \"2.0\", \"oslo.message\": \"{\\\"message_id\\\": \\\"ea20e157-d198-4196-a7d5-b23500241d4d\\\", \\\"publisher_id\\\": \\\"telemetry.publisher.controller-0.redhat.local\\\", \\\"event_type\\\": \\\"event\\\", \\\"priority\\\": \\\"SAMPLE\\\", \\\"payload\\\": [{\\\"message_id\\\": \\\"00fb3b61-607d-4d79-9b35-89413621125c\\\", \\\"event_type\\\": \\\"network.create.start\\\", \\\"generated\\\": \\\"2020-04-27T09:08:29.083808\\\", \\\"traits\\\": [[\\\"service\\\", 1, \\\"network.controller-0.redhat.local\\\"], [\\\"request_id\\\", 1, \\\"req-2520570f-7549-414c-98b2-d64ad7e0ffa0\\\"], [\\\"project_id\\\", 1, \\\"9609072e9f3b401dac5f7ace13672627\\\"], [\\\"user_id\\\", 1, \\\"e4c58a343ce845bbb61fc0b435c5b434\\\"], [\\\"tenant_id\\\", 1, \\\"9609072e9f3b401dac5f7ace13672627\\\"], [\\\"name\\\", 1, \\\"stfnet7\\\"]], \\\"raw\\\": {}, \\\"message_signature\\\": \\\"b0b658db9fbe2a81f20bf9ed3a42c52684cec5766133e68cb78063e58e883228\\\"}], \\\"timestamp\\\": \\\"2020-04-27 09:08:29.086452\\\"}\"}, \"context\": {}}")
        expect(event["payload"]["event_type"]).to eq "network.create.start"
        expect(event["payload"]["traits"].last).to eq ["name", 1, "stfnet7"]
      end

      it "parses event payload" do
        event = subject.unserialize_event("{\"request\": {\"oslo.version\": \"2.0\", \"oslo.message\": \"{\\\"message_id\\\": \\\"ea20e157-d198-4196-a7d5-b23500241d4d\\\", \\\"publisher_id\\\": \\\"telemetry.publisher.controller-0.redhat.local\\\", \\\"event_type\\\": \\\"event\\\", \\\"priority\\\": \\\"SAMPLE\\\", \\\"payload\\\": [{\\\"message_id\\\": \\\"00fb3b61-607d-4d79-9b35-89413621125c\\\", \\\"event_type\\\": \\\"network.create.start\\\", \\\"generated\\\": \\\"2020-04-27T09:08:29.083808\\\", \\\"traits\\\": [[\\\"service\\\", 1, \\\"network.controller-0.redhat.local\\\"], [\\\"request_id\\\", 1, \\\"req-2520570f-7549-414c-98b2-d64ad7e0ffa0\\\"], [\\\"project_id\\\", 1, \\\"9609072e9f3b401dac5f7ace13672627\\\"], [\\\"user_id\\\", 1, \\\"e4c58a343ce845bbb61fc0b435c5b434\\\"], [\\\"tenant_id\\\", 1, \\\"9609072e9f3b401dac5f7ace13672627\\\"], [\\\"name\\\", 1, \\\"stfnet7\\\"]], \\\"raw\\\": {}, \\\"message_signature\\\": \\\"b0b658db9fbe2a81f20bf9ed3a42c52684cec5766133e68cb78063e58e883228\\\"}], \\\"timestamp\\\": \\\"2020-04-27 09:08:29.086452\\\"}\"}, \"context\": {}}")
        expect(event["payload"]["event_type"]).to eq "network.create.start"
        expect(event["payload"]["traits"].last).to eq ["name", 1, "stfnet7"]
      end


    end

    describe 'filter events' do


    end
  end
end
