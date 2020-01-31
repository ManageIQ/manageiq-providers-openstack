describe ManageIQ::Providers::Openstack::CloudManager::AvailabilityZone do
  let(:provider) { FactoryBot.create(:provider_openstack) }
  let(:ems) { FactoryBot.create(:ems_openstack_with_authentication, :provider => provider) }
  let(:ems_infra) { FactoryBot.create(:ems_openstack_infra)}
  let(:availability_zone) { FactoryBot.create(:availability_zone_openstack, :ext_management_system => ems) }

  describe 'block_storage_disk_capacity' do
    it 'returns 0 when there is no linked undercloud' do
      provider = double
      allow(provider).to receive(:infra_ems).and_return(nil)
      expect(availability_zone.block_storage_disk_capacity).to eq(0)
    end
  end
end
