require 'manageiq/providers/openstack/legacy/events/openstack_saf_event_monitor'
require 'qpid_proton'

describe OpenstackSafEventMonitor do
  let(:qdr_options) { {:hostname => "machine.local", :port => '5666', :security_protocol => 'non-ssl'} }

  context "connecting to services" do

    it 'prepare QDR endpoint URL' do
      expect(subject.class.build_qdr_client_url(qdr_options)).to eq "amqp://machine.local:5666"
    end

    it 'test availability' do
      qdr_connection = double
      allow_any_instance_of(Qpid::Proton::Container).to \
        receive(:connect).with("amqp://machine.local:5666").and_return(qdr_connection)
      expect(qdr_connection).to receive(:close)
      expect(subject.class.available?(qdr_options)).to be true
    end

    it 'test availability failed' do
      qdr_connection = double
      allow_any_instance_of(Qpid::Proton::Container).to \
        receive(:connect).with("amqp://machine.local:5666").and_raise(Qpid::Proton::ProtonError)
      expect(subject.class.available?(qdr_options)).to be false
    end
  end

  context "collecting events" do
     # TODO
  end
end
