describe ManageIQ::Providers::Openstack::StorageManager::CinderManager::EventTargetParser do
  before :each do
    _guid, _server, zone = EvmSpecHelper.create_guid_miq_server_zone
    @ems                 = FactoryBot.create(:ems_openstack, :zone => zone)

    allow_any_instance_of(EmsEvent).to receive(:handle_event)
    allow(EmsEvent).to receive(:create_completed_event)
  end

  context "Openstack Event Parsing" do
    it "parses volume events" do
      ems_event = create_ems_event("volume.create.end", "resource_id" => "volume_id_test",)
      parsed_targets = described_class.new(ems_event).parse
      expect(parsed_targets.size).to eq(2)
      expect(target_references(parsed_targets)).to(
        match_array(
          [
            [:cloud_volumes, {:ems_ref=>"volume_id_test"}], [:volume_templates, {:ems_ref=>"volume_id_test"}]
          ]
        )
      )
    end

    it "parses snapshot events" do
      ems_event = create_ems_event("snapshot.create.end", "resource_id" => "snapshot_id_test",
                                                          "volume_id"   => "volume_id_test")
      parsed_targets = described_class.new(ems_event).parse
      expect(parsed_targets.size).to eq(2)
      expect(target_references(parsed_targets)).to(
        match_array(
          [
            [:cloud_volume_snapshots, {:ems_ref => "snapshot_id_test"}],
            [:cloud_volumes, {:ems_ref => "volume_id_test"}]
          ]
        )
      )
    end
  end

  def target_references(parsed_targets)
    parsed_targets.map { |x| [x.association, x.manager_ref] }.uniq
  end

  def create_ems_event(event_type, payload)
    event_hash = {
      :event_type => event_type,
      :source     => "OPENSTACK",
      :message    => payload,
      :timestamp  => "2016-03-13T16:59:01.760000",
      :username   => "",
      :full_data  => {:content => {'payload' => payload}},
      :ems_id     => @ems.cinder_manager.id
    }
    EmsEvent.add(@ems.cinder_manager.id, event_hash)
  end
end
