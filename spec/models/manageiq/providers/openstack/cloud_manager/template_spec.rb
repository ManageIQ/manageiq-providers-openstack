describe ManageIQ::Providers::Openstack::CloudManager::Template do
  let(:ems) { FactoryGirl.create(:ems_openstack) }
  let(:image_attributes) { {:name => 'image', :ram => '1', :url => 'url'} }
  let(:template_openstack) { FactoryGirl.create :template_openstack, :ext_management_system => ems, :ems_ref => 'one_id' }
  let(:service) { double }

  context 'when create_image' do
    before do
      allow(ems).to receive(:with_provider_connection).with(:service => 'Image').and_yield(service)
      allow(service).to receive(:images).and_return(images)
    end

    let(:images) { double }
    let(:image_fog) { double }

    context 'with correct data' do
      it 'should create image' do
        allow(images).to receive(:create).with(image_attributes.except(:url)).and_return(image_fog).once
        allow(service).to receive(:handle_upload).with(image_fog, image_attributes[:url]).and_return(true).once

        expect(images).to receive(:create).with(image_attributes.except(:url)).and_return(image_fog).once
        expect(service).to receive(:handle_upload).and_return(true)

        subject.class.create_image(ems, image_attributes)
      end

      it 'should not raise error' do
        allow(images).to receive(:create).with(image_attributes.except(:url)).and_return(image_fog).once

        expect(service).to receive(:handle_upload).and_return(true)
        expect do
          subject.class.create_image(ems, image_attributes)
        end.not_to raise_error
      end
    end

    context 'with incorrect data' do
      [Excon::Error::BadRequest, ArgumentError].map do |error|
        it "should raise error when #{error}" do
          allow(images).to receive(:create).with(image_attributes.except(:url)).and_raise(error)
          expect do
            subject.class.create_image(ems, image_attributes)
          end.to raise_error(MiqException::MiqOpenstackApiRequestError)
        end
      end
    end
  end

  context 'when update_image' do
    let(:fog_image) { double }
    let(:service) { double("Service", :images => double("Images", :find_by_id => fog_image)) }
    before do
      allow(ems).to receive(:with_provider_connection).with(:service => 'Image').and_yield(service)
      allow(template_openstack).to receive(:ext_management_system).and_return(ems)
    end

    subject { template_openstack }

    it 'should update image' do
      expect(fog_image).to receive(:update).with(image_attributes).once
      subject.update_image(image_attributes)
    end
  end

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
