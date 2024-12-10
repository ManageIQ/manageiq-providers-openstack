describe ManageIQ::Providers::Openstack::CloudManager::Provision::VolumeAttachment do
  let(:ems)          { FactoryBot.create(:ems_openstack_with_authentication) }
  let(:flavor)       { FactoryBot.create(:flavor_openstack) }
  let(:template)     { FactoryBot.create(:template_openstack, :ext_management_system => ems) }
  let(:volume)       { FactoryBot.create(:cloud_volume_openstack) }
  let(:service)      { double("volume service") }
  let(:task_options) { {:instance_type => flavor, :src_vm_id => template.id, :volumes => task_volumes} }
  let(:task_volumes) { [{:name => "custom_volume_1", :size => 2}] }
  let(:task)         { FactoryBot.create(:miq_provision_openstack, :source => template, :state => 'pending', :status => 'Ok', :options => task_options) }

  before do
    # We're storing objects in the instance_type, so we must permit loading this class
    ActiveRecord.yaml_column_permitted_classes = YamlPermittedClasses.app_yaml_permitted_classes | [flavor.class]
  end

  context "#configure_volumes" do
    before do
      allow(service).to receive_message_chain(:volumes, :create).and_return(volume)
      allow(task.source.ext_management_system).to receive(:with_provider_connection)
        .with({:service => 'volume', :tenant_name => nil}).and_yield(service)
      allow(task).to receive(:instance_type).and_return(flavor)
    end

    it "create volumes" do
      default_volume = {:name => "root", :size => 1, :source_type => "image", :destination_type => "local",
                        :boot_index => 0, :delete_on_termination => true, :uuid => nil}
      requested_volume = {:name => "custom_volume_1", :size => 2, :uuid => volume.id, :source_type => "volume",
                          :destination_type => "volume"}

      expect(task.create_requested_volumes(task.options[:volumes])).to eq([default_volume, requested_volume])
    end

    context "with a flavor that has no root disk" do
      let(:flavor) { FactoryBot.create(:flavor_openstack, :root_disk_size => 0) }

      it "sets the requested volume as a boot disk" do
        expected_volume = {:name => "custom_volume_1", :size => 2, :uuid => volume.id, :source_type => "volume",
                           :destination_type => "volume", :boot_index => 0, :bootable => true, :imageRef => template.ems_ref}

        expect(task.create_requested_volumes(task.options[:volumes])).to eq([expected_volume])
      end

      context "with multiple requested volumes" do
        let(:task_volumes) { [{:name => "custom_volume_1", :size => 2}, {:name => "custom_volume_2", :size => 4}] }

        it "only sets boot_index for first volumes" do
          expected_volume_1 = {:name => "custom_volume_1", :size => 2, :uuid => volume.id, :source_type => "volume",
                               :destination_type => "volume", :boot_index => 0, :bootable => true, :imageRef => template.ems_ref}
          expected_volume_2 = {:name => "custom_volume_2", :size => 4, :uuid => volume.id, :source_type => "volume",
                               :destination_type => "volume"}

          expect(task.create_requested_volumes(task.options[:volumes])).to eq([expected_volume_1, expected_volume_2])
        end
      end
    end
  end

  context "#check_volumes" do
    it "status pending" do
      pending_volume_attrs = {:source_type => "volume"}

      allow(service).to receive_message_chain('volumes.get')
        .and_return(FactoryBot.build(:cloud_volume_openstack, :status => "pending"))
      allow(task.source.ext_management_system).to receive(:with_provider_connection)
        .with({:service => 'volume', :tenant_name => nil}).and_yield(service)

      expect(task.do_volume_creation_check([pending_volume_attrs])).to eq([false, "pending"])
    end

    it "check creation status available" do
      pending_volume_attrs = {:source_type => "volume"}

      allow(service).to receive_message_chain('volumes.get')
        .and_return(FactoryBot.build(:cloud_volume_openstack, :status => "available"))
      allow(task.source.ext_management_system).to receive(:with_provider_connection)
        .with({:service => 'volume', :tenant_name => nil}).and_yield(service)

      expect(task.do_volume_creation_check([pending_volume_attrs])).to be_truthy
    end

    it "check creation status - not found" do
      pending_volume_attrs = {:source_type => "volume"}

      allow(service).to receive_message_chain('volumes.get').and_return(nil)
      allow(task.source.ext_management_system).to receive(:with_provider_connection)
        .with({:service => 'volume', :tenant_name => nil}).and_yield(service)

      expect(task.do_volume_creation_check([pending_volume_attrs])).to eq([false, nil])
    end

    it "status error" do
      pending_volume_attrs = {:source_type => "volume"}

      allow(service).to receive_message_chain('volumes.get')
        .and_return(FactoryBot.build(:cloud_volume_openstack, :status => "error"))
      allow(task.source.ext_management_system).to receive(:with_provider_connection)
        .with({:service => 'volume', :tenant_name => nil}).and_yield(service)

      expect { task.do_volume_creation_check([pending_volume_attrs]) }.to raise_error(MiqException::MiqProvisionError)
    end
  end
end
