describe ManageIQ::Providers::Openstack::StorageManager::CinderManager::CloudVolumeBackup do
  let(:ems) { FactoryBot.create(:ems_openstack_cinder) }
  let(:tenant) { FactoryBot.create(:cloud_tenant_openstack, :ext_management_system => ems.parent_manager, :name => 'test') }
  let(:raw_cloud_volume_backup) { double }

  let(:cloud_volume) do
    FactoryBot.create(:cloud_volume_openstack,
                       :ext_management_system => ems,
                       :name                  => 'test',
                       :ems_ref               => 'one_id',
                       :cloud_tenant          => tenant)
  end

  let(:cloud_volume_backup) do
    FactoryBot.create(:cloud_volume_backup_openstack,
                       :ext_management_system => ems,
                       :name                  => 'test backup',
                       :ems_ref               => 'two_id',
                       :cloud_volume          => cloud_volume)
  end

  before do
    allow(cloud_volume_backup).to receive(:cloud_tenant).and_return(tenant)
    allow(cloud_volume_backup).to receive(:with_provider_object).and_yield(raw_cloud_volume_backup)
    allow(raw_cloud_volume_backup).to receive(:destroy)
    allow(raw_cloud_volume_backup).to receive(:restore)
  end

  it "handles cloud volume" do
    expect(cloud_volume_backup.cloud_volume).to eq(cloud_volume)
  end

  context 'raw_backup_restore' do
    it 'restores backup' do
      NotificationType.seed

      expect(raw_cloud_volume_backup).to receive(:restore)
      cloud_volume_backup.raw_restore(cloud_volume)
    end

    it "raises a success notification when raw_backup_restore succeeds" do
      NotificationType.seed

      expect(raw_cloud_volume_backup).to receive(:restore)
      cloud_volume_backup.raw_restore(cloud_volume)
      note = Notification.find_by(:notification_type_id => NotificationType.find_by(:name => "cloud_volume_backup_restore_success").id)
      expect(note.options).to eq(:subject => cloud_volume_backup.name, :volume_name => cloud_volume.name)
    end

    it "raises an error notification when raw_backup_restore fails" do
      NotificationType.seed
      error_message = "restore failed"
      expect(raw_cloud_volume_backup).to receive(:restore).and_raise(error_message)
      expect { cloud_volume_backup.raw_restore(cloud_volume) }.to raise_error(error_message)
      note = Notification.find_by(:notification_type_id => NotificationType.find_by(:name => "cloud_volume_backup_restore_error").id)
      expect(note.options).to eq(:subject => cloud_volume_backup.name, :volume_name => cloud_volume.name, :error_message => error_message)
    end
  end

  context 'raw_delete_backup' do
    it 'deletes backup' do
      NotificationType.seed

      expect(raw_cloud_volume_backup).to receive(:destroy)
      cloud_volume_backup.raw_delete
    end

    it "raises a success notification when raw_delete_backup succeeds" do
      NotificationType.seed

      expect(raw_cloud_volume_backup).to receive(:destroy)
      cloud_volume_backup.raw_delete
      note = Notification.find_by(:notification_type_id => NotificationType.find_by(:name => "cloud_volume_backup_delete_success").id)
      expect(note.options).to eq(:subject => cloud_volume_backup.name, :volume_name => cloud_volume.name)
    end

    it "raises an error notification when raw_delete_backup fails" do
      NotificationType.seed
      error_message = "backup failed"
      expect(raw_cloud_volume_backup).to receive(:destroy).and_raise(error_message)
      expect { cloud_volume_backup.raw_delete }.to raise_error(error_message)
      note = Notification.find_by(:notification_type_id => NotificationType.find_by(:name => "cloud_volume_backup_delete_error").id)
      expect(note.options).to eq(:subject => cloud_volume_backup.name, :volume_name => cloud_volume.name, :error_message => error_message)
    end
  end
end
