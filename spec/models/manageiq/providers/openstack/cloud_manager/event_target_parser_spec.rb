describe ManageIQ::Providers::Openstack::CloudManager::EventTargetParser do
  before :each do
    _guid, _server, zone = EvmSpecHelper.create_guid_miq_server_zone
    @ems                 = FactoryGirl.create(:ems_openstack, :zone => zone)

    allow_any_instance_of(EmsEvent).to receive(:handle_event)
    allow(EmsEvent).to receive(:create_completed_event)
  end

  context "Openstack Event Parsing" do
    it "parses compute.instance events" do
      ems_event = create_ems_event("compute.instance.create.end", "instance_id" => "instance_id_test",
                                                                  "tenant_id"   => "tenant_id_test")
      parsed_targets = described_class.new(ems_event).parse
      expect(parsed_targets.size).to eq(2)
      expect(target_references(parsed_targets)).to(
        match_array(
          [
            [:vms, {:ems_ref => "instance_id_test"}],
            [:cloud_tenants, {:ems_ref => "tenant_id_test"}]
          ]
        )
      )
    end

    it "parses identity.project events" do
      ems_event = create_ems_event("identity.project.create.end", "project_id" => "tenant_id_test")
      parsed_targets = described_class.new(ems_event).parse
      expect(parsed_targets.size).to eq(1)
      expect(target_references(parsed_targets)).to(
        match_array(
          [
            [:cloud_tenants, {:ems_ref => "tenant_id_test"}]
          ]
        )
      )
    end

    it "parses orchestration.stack events" do
      ems_event = create_ems_event("orchestration.stack.create.end", "stack_id" => "stack_id_test")
      parsed_targets = described_class.new(ems_event).parse
      expect(parsed_targets.size).to eq(1)
      expect(target_references(parsed_targets)).to(
        match_array(
          [
            [:orchestration_stacks, {:ems_ref => "stack_id_test"}]
          ]
        )
      )
    end

    it "parses image events" do
      ems_event = create_ems_event("image.create.end", "resource_id" => "image_id_test")
      parsed_targets = described_class.new(ems_event).parse
      expect(parsed_targets.size).to eq(2)
      expect(target_references(parsed_targets)).to(
        match_array(
          [
            [:images, {:ems_ref=>"image_id_test"}], [:miq_templates, {:ems_ref=>"image_id_test"}]
          ]
        )
      )
    end

    it "parses host aggregate events" do
      ems_event = create_ems_event("aggregate.create.end", "service" => "aggregate.id_test")
      parsed_targets = described_class.new(ems_event).parse
      expect(parsed_targets.size).to eq(1)
      expect(target_references(parsed_targets)).to(
        match_array(
          [
            [:host_aggregates, {:ems_ref => "id_test"}]
          ]
        )
      )
    end

    it "doesn't create duplicate events" do
      create_ems_event("compute.instance.create.start", "service" => "compute")
      # these two should have identical timestamps, event_types, and ems_ids,
      # so they are probably duplicate events. As such, only one EmsEvent
      # should be created.
      create_ems_event("compute.instance.create.end", "service" => "compute")
      create_ems_event("compute.instance.create.end", "service" => "compute")
      expect(EmsEvent.all.count).to eq(2)
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
      :ems_id     => @ems.id
    }
    EmsEvent.add(@ems.id, event_hash)
  end
end
