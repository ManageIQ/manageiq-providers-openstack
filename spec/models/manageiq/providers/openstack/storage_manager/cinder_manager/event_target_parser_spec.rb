describe ManageIQ::Providers::Openstack::StorageManager::CinderManager::EventTargetParser do
  before :each do
    zone     = EvmSpecHelper.local_miq_server.zone
    @ems     = FactoryBot.create(:ems_openstack, :zone => zone)
    @manager = @ems.cinder_manager

    allow_any_instance_of(EmsEvent).to receive(:handle_event)
    allow(EmsEvent).to receive(:create_completed_event)
  end

  context "Openstack Event Parsing" do
    [true, false].each do |oslo_message|
      oslo_message_text = "with#{"out" unless oslo_message} oslo_message"

      it "parses volume events #{oslo_message_text}" do
        payload = {"resource_id" => "volume_id_test"}
        ems_event = create_ems_event(@manager, "volume.create.end", oslo_message, payload)

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

      it "parses snapshot events #{oslo_message_text}" do
        payload = {
          "resource_id" => "snapshot_id_test",
          "volume_id"   => "volume_id_test"
        }
        ems_event = create_ems_event(@manager, "snapshot.create.end", oslo_message, payload)

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
  end

  def target_references(parsed_targets)
    parsed_targets.map { |x| [x.association, x.manager_ref] }.uniq
  end
end
