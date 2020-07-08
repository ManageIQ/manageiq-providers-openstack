describe ManageIQ::Providers::Openstack::CloudManager::EventTargetParser do
  before :each do
    _guid, _server, zone = EvmSpecHelper.create_guid_miq_server_zone
    @ems                 = FactoryBot.create(:ems_openstack, :zone => zone)

    allow_any_instance_of(EmsEvent).to receive(:handle_event)
    allow(EmsEvent).to receive(:create_completed_event)
  end

  context "Openstack Event Parsing" do
    [true, false].each do |oslo_message|
      oslo_message_text = "with#{"out" unless oslo_message} oslo_message"

      it "parses compute.instance events #{oslo_message_text}" do
        payload = {
          "instance_id" => "instance_id_test",
          "tenant_id"   => "tenant_id_test"
        }
        ems_event = create_ems_event("compute.instance.create.end", oslo_message, payload)

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

      it "parses identity.project events #{oslo_message_text}" do
        payload = {"project_id" => "tenant_id_test"}
        ems_event = create_ems_event("identity.project.create.end", oslo_message, payload)

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

      it "parses orchestration.stack events #{oslo_message_text}" do
        payload = {"stack_id" => "stack_id_test"}
        ems_event = create_ems_event("orchestration.stack.create.end", oslo_message, payload)

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

      it "parses image events #{oslo_message_text}" do
        payload = {"resource_id" => "image_id_test"}
        ems_event = create_ems_event("image.create.end", oslo_message, payload)

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

      it "parses host aggregate events #{oslo_message_text}" do
        payload = {"service" => "aggregate.id_test"}
        ems_event = create_ems_event("aggregate.create.end", oslo_message, payload)

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

      it "doesn't create duplicate events #{oslo_message_text}" do
        payload = {"service" => "compute"}
        create_ems_event("compute.instance.create.start", oslo_message, payload)
        # these two should have identical timestamps, event_types, and ems_ids,
        # so they are probably duplicate events. As such, only one EmsEvent
        # should be created.
        create_ems_event("compute.instance.create.end", oslo_message, payload)
        create_ems_event("compute.instance.create.end", oslo_message, payload)
        expect(EmsEvent.all.count).to eq(2)
      end
    end
  end

  def target_references(parsed_targets)
    parsed_targets.map { |x| [x.association, x.manager_ref] }.uniq
  end

  def create_ems_event(event_type, oslo_message, payload)
    full_data =
      if oslo_message
        {:content => {'oslo.message' => {'payload' => payload}.to_json}}
      else
        {:content => {'payload' => payload}}
      end

    event_hash = {
      :event_type => event_type,
      :source     => "OPENSTACK",
      :message    => payload,
      :timestamp  => "2016-03-13T16:59:01.760000",
      :username   => "",
      :full_data  => full_data,
      :ems_id     => @ems.id
    }
    EmsEvent.add(@ems.id, event_hash)
  end
end
