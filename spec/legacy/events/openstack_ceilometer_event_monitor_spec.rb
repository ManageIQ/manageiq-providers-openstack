require 'manageiq/providers/openstack/legacy/events/openstack_ceilometer_event_monitor'

describe OpenstackCeilometerEventMonitor do
  context "connecting to services" do
    it 'sets query options for Panko' do
      ems_double = double
      allow(subject.class).to receive(:connect_service_from_settings).and_return nil
      allow(ems_double).to receive(:connect).with(:service => 'Event')
      allow(ems_double).to receive(:api_version).and_return 'v3'
      subject.instance_variable_set(:@ems, ems_double)
      allow(subject).to receive(:latest_event_timestamp).and_return nil

      subject.provider_connection
      expect(subject.send(:query_options)).to eq([{
                                                   'field' => 'start_timestamp',
                                                   'op'    => 'ge',
                                                   'value' => ''
                                                 }, {
                                                   'field' => 'all_tenants',
                                                   'value' => 'True'
                                                 }])
    end

    it 'sets query options for Panko with keystone v2' do
      ems_double = double
      allow(subject.class).to receive(:connect_service_from_settings).and_return nil
      allow(ems_double).to receive(:connect).with(:service => 'Event')
      allow(ems_double).to receive(:api_version).and_return 'v2'
      subject.instance_variable_set(:@ems, ems_double)
      allow(subject).to receive(:latest_event_timestamp).and_return nil

      subject.provider_connection
      expect(subject.send(:query_options)).to eq([{
                                                   'field' => 'start_timestamp',
                                                   'op'    => 'ge',
                                                   'value' => ''
                                                 }])
    end

    it 'sets query options for Ceilometer' do
      ems_double = double
      allow(subject.class).to receive(:connect_service_from_settings).and_return nil
      allow(ems_double).to receive(:connect).with(:service => 'Event').and_raise(MiqException::ServiceNotAvailable)
      allow(ems_double).to receive(:connect).with(:service => 'Metering')
      allow(ems_double).to receive(:api_version).and_return 'v2'
      subject.instance_variable_set(:@ems, ems_double)
      allow(subject).to receive(:latest_event_timestamp).and_return nil

      subject.provider_connection
      expect(subject.send(:query_options)).to eq([{
                                                   'field' => 'start_timestamp',
                                                   'op'    => 'ge',
                                                   'value' => ''
                                                 }])
    end
  end

  context "collecting events" do
    it 'query ceilometer nothing new' do
      connection = double
      fog_out = double
      allow(subject).to receive(:provider_connection).and_return connection
      allow(subject).to receive(:latest_event_timestamp).and_return nil
      expect(connection).to receive(:list_events).and_return fog_out
      expect(fog_out).to receive(:body).and_return []
      subject.start
      subject.each_batch do |events|
        expect(events.empty?).to be true
        subject.stop
      end
    end

    it 'query ceilometer new event' do
      connection = double
      event_data = OpenStruct.new
      event_data.event_type = 'compute.blah.start'
      event_data.generated = '2016-03-14T14:22:00.000'
      event_data.traits = [{"type" => "string", "name" => "tenant_id", "value" => "d3e8e3c7026441a98078cb1"}]
      allow(subject).to receive(:provider_connection).and_return connection
      allow(subject).to receive(:latest_event_timestamp).and_return nil
      expect(subject).to receive(:list_events).and_return [event_data]
      subject.start
      subject.each_batch do |events|
        expected_payload = {
          "event_type" => 'compute.blah.start',
          "message_id" => nil,
          "payload"    => {
            "tenant_id" => "d3e8e3c7026441a98078cb1"
          },
          "timestamp"  => "2016-03-14T14:22:00.000"
        }
        expect(events.length).to eq 1
        expect(events.first.class.name).to eq 'OpenstackEvent'
        expect(events.first.payload).to eq expected_payload
        subject.stop
      end
    end

    it 'sets query options for Panko with events history' do
      ems_double = double(:created_on => Time.now.utc, :ems_events => [])
      allow(subject.class).to receive(:connect_service_from_settings).and_return nil
      allow(ems_double).to receive(:connect).with(:service => 'Event')
      allow(ems_double).to receive(:ems_events).and_return double(:maximum => nil)
      allow(ems_double).to receive(:api_version).and_return 'v3'
      subject.instance_variable_set(:@ems, ems_double)

      allow(subject).to receive(:skip_history?).and_return false

      subject.provider_connection
      expect(subject.send(:query_options)).to eq([{
                                                   'field' => 'start_timestamp',
                                                   'op'    => 'ge',
                                                   'value' => ''
                                                 }, {
                                                   'field' => 'all_tenants',
                                                   'value' => 'True'
                                                 }])
    end

    it 'sets query options for Panko without events history' do
      ems_double = double(:created_on => Time.now.utc, :ems_events => [])
      allow(subject.class).to receive(:connect_service_from_settings).and_return nil
      allow(ems_double).to receive(:connect).with(:service => 'Event')
      allow(ems_double).to receive(:ems_events).and_return double(:maximum => nil)
      allow(ems_double).to receive(:api_version).and_return 'v3'
      subject.instance_variable_set(:@ems, ems_double)

      allow(subject).to receive(:skip_history?).and_return true

      subject.provider_connection
      expect(subject.send(:query_options)).to eq([{
                                                   'field' => 'start_timestamp',
                                                   'op'    => 'ge',
                                                   'value' => ems_double.created_on.iso8601
                                                 }, {
                                                   'field' => 'all_tenants',
                                                   'value' => 'True'
                                                 }])
    end
  end
end
