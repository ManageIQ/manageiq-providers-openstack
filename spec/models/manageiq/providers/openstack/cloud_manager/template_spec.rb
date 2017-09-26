describe ManageIQ::Providers::Openstack::CloudManager::Template do
  let(:ems) { FactoryGirl.create(:ems_openstack_with_authentication) }
  let(:template_openstack) { FactoryGirl.create :template_openstack, :ext_management_system => ems, :ems_ref => 'one_id' }
  let(:service) { double }

  context 'when raw_delete_image' do
    before do
      allow(ExtManagementSystem).to receive(:find).with(ems.id).and_return(ems)
      allow(ems).to receive(:with_provider_connection).with(:service => 'Image').and_yield(service)
    end

    subject { template_openstack }

    it 'should delete image' do
      expect(service).to receive(:delete_image).with(template_openstack.ems_ref).once
      subject.delete_image
    end

    it 'should raise error' do
      allow(service).to receive(:delete_image).with(template_openstack.ems_ref).and_raise(Excon::Error::BadRequest)
      expect do
        subject.delete_image
      end.to raise_error(MiqException::MiqOpenstackApiRequestError)
    end
  end
end
