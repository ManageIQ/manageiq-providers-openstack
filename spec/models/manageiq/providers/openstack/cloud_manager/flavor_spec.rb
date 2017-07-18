describe ManageIQ::Providers::Openstack::CloudManager::Flavor do
  let(:ems) { FactoryGirl.create(:ems_openstack_with_authentication) }
  let(:flavor_attributes) { {:name => "flavor", :ram => "1"} }
  let(:flavor_openstack) { FactoryGirl.create :flavor_openstack, :ext_management_system => ems }
  let(:service) { double }

  context 'when raw_create_flavor' do
    before do
      allow(ExtManagementSystem).to receive(:find).with(ems.id).and_return(ems)
      allow(ems).to receive(:with_provider_connection).with(:service => 'Compute').and_yield(service)
      allow(service).to receive(:flavors).and_return(flavors)
    end

    let(:flavors) { double }

    context 'with correct data' do
      it 'should create flavor' do
        expect(flavors).to receive(:create).with(flavor_attributes).and_return(flavor_openstack).once
        subject.class.raw_create_flavor(ems, flavor_attributes)
      end

      it 'should not raise error' do
        allow(flavors).to receive(:create).with(flavor_attributes).and_return(flavor_openstack).once
        expect do
          subject.class.raw_create_flavor(ems, flavor_attributes)
        end.not_to raise_error
      end
    end

    context 'with incorrect data' do
      let(:flavor_attributes) { { :ram => "1"} } # missing :name
      [Excon::Error::BadRequest, ArgumentError].map do |error|
        it "should raise error when #{error.to_s}" do
          allow(flavors).to receive(:create).with(flavor_attributes).and_raise(error)
          expect do
            subject.class.raw_create_flavor(ems, flavor_attributes)
          end.to raise_error(MiqException::MiqOpenstackApiRequestError)
        end
      end
    end
  end

  context 'when raw_delete_flavor' do
    before do
      allow(ExtManagementSystem).to receive(:find).with(ems.id).and_return(ems)
      allow(ems).to receive(:with_provider_connection).with(:service => 'Compute').and_yield(service)
    end

    subject { flavor_openstack }

    it 'should delete flavor' do
      expect(service).to receive(:delete_flavor).once
      subject.raw_delete_flavor
    end

    it 'should raise error' do
      allow(service).to receive(:delete_flavor).and_raise(Excon::Error::BadRequest)
      expect do
        subject.raw_delete_flavor
      end.to raise_error(MiqException::MiqOpenstackApiRequestError)
    end
  end

  context 'when validations' do
    it 'fails with invalid parameters' do
      expect(subject.class.validate_create_flavor(nil)).to eq(
        :available => false,
        :message   => 'The Flavor is not connected to an active Provider')
    end

    it 'doesn`t fail with valid parameters' do
      expect(subject.class.validate_create_flavor(ems)).to eq(
        :available => true,
        :message   => nil)
    end
  end
end
