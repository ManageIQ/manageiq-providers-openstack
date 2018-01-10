describe ManageIQ::Providers::Openstack::NetworkManager::EventTargetParser do
  before :each do
    _guid, _server, zone = EvmSpecHelper.create_guid_miq_server_zone
    @ems                 = FactoryGirl.create(:ems_openstack, :zone => zone)

    allow_any_instance_of(EmsEvent).to receive(:handle_event)
    allow(EmsEvent).to receive(:create_completed_event)
  end

  context "Openstack Event Parsing" do
    it "parses network events" do
      ems_event = create_ems_event("network.create.end", "resource_id" => "network_id_test",)
      parsed_targets = described_class.new(ems_event).parse
      expect(parsed_targets.size).to eq(1)
      expect(target_references(parsed_targets)).to(
        match_array(
          [
            [:networks, {:ems_ref => "network_id_test"}]
          ]
        )
      )
    end

    it "parses router events" do
      ems_event = create_ems_event("router.create.end", "resource_id" => "router_id_test",)
      parsed_targets = described_class.new(ems_event).parse
      expect(parsed_targets.size).to eq(1)
      expect(target_references(parsed_targets)).to(
        match_array(
          [
            [:routers, {:ems_ref => "router_id_test"}]
          ]
        )
      )
    end

    it "parses port events" do
      ems_event = create_ems_event("port.create.end", "resource_id" => "port_id_test",)
      parsed_targets = described_class.new(ems_event).parse
      expect(parsed_targets.size).to eq(1)
      expect(target_references(parsed_targets)).to(
        match_array(
          [
            [:ports, {:ems_ref => "port_id_test"}]
          ]
        )
      )
    end

    it "parses floating ip events" do
      ems_event = create_ems_event("floatingip.create.end", "resource_id" => "floating_ip_id_test",)
      parsed_targets = described_class.new(ems_event).parse
      expect(parsed_targets.size).to eq(1)
      expect(target_references(parsed_targets)).to(
        match_array(
          [
            [:floating_ips, {:ems_ref => "floating_ip_id_test"}]
          ]
        )
      )
    end

    it "parses security_group events" do
      ems_event = create_ems_event("security_group.create.end", "resource_id" => "security_group_id_test",)
      parsed_targets = described_class.new(ems_event).parse
      expect(parsed_targets.size).to eq(1)
      expect(target_references(parsed_targets)).to(
        match_array(
          [
            [:security_groups, {:ems_ref => "security_group_id_test"}]
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
      :full_data  => {:payload => payload },
      :ems_id     => @ems.network_manager.id
    }
    EmsEvent.add(@ems.network_manager.id, event_hash)
  end
end
