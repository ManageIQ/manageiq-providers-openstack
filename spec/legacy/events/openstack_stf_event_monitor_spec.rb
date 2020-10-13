require 'manageiq/providers/openstack/legacy/events/openstack_stf_event_monitor'

describe OpenstackStfEventMonitor, :qpid_proton => true do
  before(:all) do
    require 'qpid_proton'
  end

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
    end

    describe 'filter events' do
      let(:compute_event) do
        converted_event = OpenstackStfEventConverter.new(
          "event_type" => "event", "priority" => "SAMPLE", "payload" => {"event_type" => "compute.instance.create.start",
          "generated" => "2020-04-27T09:08:29.083808", "message_id" => "00fb3b61-607d-4d79-9b35-89413621125c",
          "traits" => [["resource_id", 1, "00fb3b84-614d-4d58-9b36-898426211282"]]}, "timestamp" => "2020-04-27 09:08:29.086452"
        )
        subject.send(:openstack_event, nil, converted_event.metadata, converted_event.payload)
      end
      let(:network_event) do
        converted_event = OpenstackStfEventConverter.new(
          "event_type" => "event", "priority" => "SAMPLE", "payload" => {"event_type" => "network.create.start",
          "generated" => "2020-04-27T09:08:28.083808", "message_id" => "00cb3b61-607d-4d80-9b35-89413621164a",
          "traits" => [["name", 1, "stfnet7"]]}, "timestamp" => "2020-04-27 09:08:28.086452"
        )
        subject.send(:openstack_event, nil, converted_event.metadata, converted_event.payload)
      end

      it "accept expected Compute event" do
        captured_events = [network_event, compute_event]
        subject.instance_variable_set(
          :@config,
          :topic_name => "anycast/ceilometer/event.sample", :event_types_regex => '\A(aggregate|compute\.instance|identity\.project|image)'
        )
        expect(subject.filter_event_types(captured_events)).to eq [compute_event]
      end
    end
  end
end
