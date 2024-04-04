describe ManageIQ::Providers::Openstack::StorageManager::CinderManager::CloudVolume do
  let(:ems) { FactoryBot.create(:ems_openstack_cinder) }
  let(:tenant) { FactoryBot.create(:cloud_tenant_openstack, :ext_management_system => ems.parent_manager) }
  let(:cloud_volume) do
    FactoryBot.create(:cloud_volume_openstack,
                       :ext_management_system => ems,
                       :name                  => 'test',
                       :ems_ref               => 'one_id',
                       :cloud_tenant          => tenant)
  end

  let(:the_raw_volume) do
    double.tap do |volume|
      allow(volume).to receive(:id).and_return('one_id')
      allow(volume).to receive(:status).and_return('available')
      allow(volume).to receive(:attributes).and_return({})
      allow(volume).to receive(:save).and_return(volume)
    end
  end

  let(:raw_volumes) do
    double.tap do |volumes|
      allow(ExtManagementSystem).to receive(:find).with(ems.id).and_return(ems)
      allow(ExtManagementSystem).to receive(:find).with(ems.parent_manager.id).and_return(ems.parent_manager)
      allow(ems.parent_manager).to receive(:connect)
                               .with(hash_including(:service => 'Volume', :tenant_name => tenant.name))
                               .and_return(double(:volumes => volumes))
      allow(volumes).to receive(:get).with(cloud_volume.ems_ref).and_return(the_raw_volume)
    end
  end

  before do
    raw_volumes
  end

  describe 'volume actions' do
    context ".create_volume" do
      let(:the_new_volume) { double }
      let(:volume_options) { {"cloud_tenant_id" => tenant.id, "name" => "new_name", "size" => 2} }

      before do
        NotificationType.seed
        allow(raw_volumes).to receive(:new).and_return(the_new_volume)
      end

      it 'creates a volume' do
        allow(the_new_volume).to receive("id").and_return('new_id')
        allow(the_new_volume).to receive("status").and_return('creating')
        expect(the_new_volume).to receive(:save).and_return(the_new_volume)

        volume = CloudVolume.create_volume(ems.id, volume_options)
        expect(volume.class).to        eq Hash
        expect(volume[:name]).to       eq 'new_name'
        expect(volume[:ems_ref]).to    eq 'new_id'
        expect(volume[:status]).to     eq 'creating'
      end

      it "raises an error when the ems is missing" do
        expect { CloudVolume.create_volume(nil) }.to raise_error(ArgumentError)
      end

      it "supports the cloud volume create operation" do
        expect(ems.supports?(:cloud_volume_create)).to be true
      end

      it 'catches errors from provider' do
        expect(the_new_volume).to receive(:save).and_raise('bad request')

        expect { CloudVolume.create_volume(ems.id, volume_options) }.to raise_error(MiqException::MiqVolumeCreateError)
      end
    end

    context "#update_volume" do
      before { NotificationType.seed }

      it 'updates the volume' do
        expect(the_raw_volume).to receive(:save)
        expect(the_raw_volume).to receive(:size)
        cloud_volume.update_volume({})
      end

      it "validates the volume update operation" do
        expect(cloud_volume.supports?(:update)).to be_truthy
      end

      it "validates the volume update operation when ems is missing" do
        cloud_volume.ext_management_system = nil
        expect(cloud_volume.supports?(:update)).to be_falsy
        expect(cloud_volume.unsupported_reason(:update)).to eq("The Volume is not connected to an active Provider")
      end

      it 'catches errors from provider' do
        expect(the_raw_volume).to receive(:save).and_raise('bad request')
        expect { cloud_volume.update_volume({}) }.to raise_error(MiqException::MiqVolumeUpdateError)
      end
    end

    context "#delete_volume" do
      before { NotificationType.seed }

      it "validates the volume delete operation when status is in-use" do
        expect(cloud_volume).to receive(:status).and_return("in-use")
        expect(cloud_volume.supports?(:delete)).to be false
      end

      it "validates the volume delete operation when status is available" do
        expect(cloud_volume).to receive(:status).and_return("available")
        expect(cloud_volume.supports?(:delete)).to be true
      end

      it "validates the volume delete operation when status is error" do
        expect(cloud_volume).to receive(:status).and_return("error")
        expect(cloud_volume.supports?(:delete)).to be true
      end

      it "validates the volume delete operation when ems is missing" do
        expect(cloud_volume).to receive(:ext_management_system).and_return(nil)
        expect(cloud_volume.supports?(:delete)).to be false
      end

      it 'updates the volume' do
        expect(the_raw_volume).to receive(:destroy)
        cloud_volume.delete_volume
      end

      it 'catches errors from provider' do
        expect(the_raw_volume).to receive(:destroy).and_raise('bad request')
        expect { cloud_volume.delete_volume }.to raise_error(MiqException::MiqVolumeDeleteError)
      end
    end

    context "#backup_create" do
      let(:fog_backup) do
        double.tap do |fog_backup|
          allow(fog_backup).to receive(:save)
        end
      end

      let(:fog_backups) do
        double.tap do |fog_backups|
          volume_service = double
          allow(volume_service).to receive(:backups).and_return(fog_backups)
          allow(ExtManagementSystem).to receive(:find).with(ems.id).and_return(ems)
          allow(ExtManagementSystem).to receive(:find).with(ems.parent_manager.id).and_return(ems.parent_manager)
          allow(ems.parent_manager).to receive(:connect)
                                   .with(hash_including(:service => 'Volume', :tenant_name => tenant.name))
                                   .and_return(volume_service)
          allow(fog_backups).to receive(:new).and_return(fog_backup)
        end
      end

      before do
        NotificationType.seed
        fog_backups
      end

      it "raises a success notification when backup_create succeeds" do
        cloud_volume.backup_create(:name => "my_backup")

        note = Notification.find_by(:notification_type_id => NotificationType.find_by(:name => "cloud_volume_backup_create_success").id)
        expect(note.options).to eq(:subject => cloud_volume.name, :backup_name => "my_backup")
      end

      it "raises an error notification when backup_create fails" do
        error_message = "backup_create failed"
        expect(fog_backups).to receive(:new).and_raise(error_message)
        expect { cloud_volume.backup_create(:name => "my_backup") }.to raise_error(error_message)

        note = Notification.find_by(:notification_type_id => NotificationType.find_by(:name => "cloud_volume_backup_create_error").id)
        expect(note.options).to eq(:subject => cloud_volume.name, :backup_name => "my_backup", :error_message => error_message)
      end
    end
  end

  describe "instance linsting for attaching volumes" do
    let(:first_instance) { FactoryBot.create(:vm_openstack, :ext_management_system => ems, :ems_ref => "instance_0", :cloud_tenant => tenant) }
    let(:second_instance) { FactoryBot.create(:vm_openstack, :ext_management_system => ems, :ems_ref => "instance_1", :cloud_tenant => tenant) }
    let(:other_tenant) { FactoryBot.create(:cloud_tenant_openstack, :ext_management_system => ems) }
    let(:other_instance) { FactoryBot.create(:vm_openstack, :ext_management_system => ems, :ems_ref => "instance_2", :cloud_tenant => other_tenant) }

    it "supports attachment to only those instances that are in the same tenant" do
      expect(cloud_volume.available_vms).to contain_exactly(first_instance, second_instance)
    end

    it "should exclude instances that are already attached to the volume" do
      attached_instance = FactoryBot.create(:vm_openstack, :ext_management_system => ems, :ems_ref => "attached_instance", :cloud_tenant => tenant)
      allow(cloud_volume).to receive(:vms).and_return([attached_instance])
      expect(cloud_volume.available_vms).to contain_exactly(first_instance, second_instance)
    end
  end
end
