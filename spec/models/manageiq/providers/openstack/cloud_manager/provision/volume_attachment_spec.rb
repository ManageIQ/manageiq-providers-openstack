describe ManageIQ::Providers::Openstack::CloudManager::Provision::VolumeAttachment do
  before do
    @ems = FactoryBot.create(:ems_openstack_with_authentication)
    @template = FactoryBot.create(:template_openstack, :ext_management_system => @ems)
    @flavor = FactoryBot.create(:flavor_openstack)
    @volume = FactoryBot.create(:cloud_volume_openstack)

    # We're storing objects in the instance_type, so we must permit loading this class
    ActiveRecord::Base.yaml_column_permitted_classes = ActiveRecord::Base.yaml_column_permitted_classes | [@flavor.class]
    @task = FactoryBot.create(:miq_provision_openstack,
                               :source  => @template,
                               :state   => 'pending',
                               :status  => 'Ok',
                               :options => {
                                 :instance_type => @flavor,
                                 :src_vm_id     => @template.id,
                                 :volumes       => [{:name => "custom_volume_1", :size => 2}]
                               })
  end

  context "#configure_volumes" do
    it "create volumes" do
      service = double
      allow(service).to receive_message_chain('volumes.create').and_return @volume
      allow(@task.source.ext_management_system).to receive(:with_provider_connection)\
        .with({:service => 'volume', :tenant_name => nil}).and_yield(service)
      allow(@task).to receive(:instance_type).and_return @flavor

      default_volume = {:name => "root", :size => 1, :source_type => "image", :destination_type => "local",
                        :boot_index => 0, :delete_on_termination => true, :uuid => nil}
      requested_volume = {:name => "custom_volume_1", :size => 2, :uuid => @volume.id, :source_type => "volume",
                          :destination_type => "volume"}

      expect(@task.create_requested_volumes(@task.options[:volumes])).to eq [default_volume, requested_volume]
    end
  end

  context "#check_volumes" do
    it "status pending" do
      pending_volume_attrs = {:source_type => "volume"}
      service = double
      allow(service).to receive_message_chain('volumes.get').and_return FactoryBot.build(:cloud_volume_openstack,
                                                                                          :status => "pending")
      allow(@task.source.ext_management_system).to receive(:with_provider_connection)\
        .with({:service => 'volume', :tenant_name => nil}).and_yield(service)

      expect(@task.do_volume_creation_check([pending_volume_attrs])).to eq [false, "pending"]
    end

    it "check creation status available" do
      pending_volume_attrs = {:source_type => "volume"}
      service = double
      allow(service).to receive_message_chain('volumes.get').and_return FactoryBot.build(:cloud_volume_openstack,
                                                                                          :status => "available")
      allow(@task.source.ext_management_system).to receive(:with_provider_connection)\
        .with({:service => 'volume', :tenant_name => nil}).and_yield(service)

      expect(@task.do_volume_creation_check([pending_volume_attrs])).to eq true
    end

    it "check creation status - not found" do
      pending_volume_attrs = {:source_type => "volume"}
      service = double
      allow(service).to receive_message_chain('volumes.get').and_return nil
      allow(@task.source.ext_management_system).to receive(:with_provider_connection)\
        .with({:service => 'volume', :tenant_name => nil}).and_yield(service)

      expect(@task.do_volume_creation_check([pending_volume_attrs])).to eq [false, nil]
    end

    it "status error" do
      pending_volume_attrs = {:source_type => "volume"}
      service = double
      allow(service).to receive_message_chain('volumes.get').and_return FactoryBot.build(:cloud_volume_openstack,
                                                                                          :status => "error")
      allow(@task.source.ext_management_system).to receive(:with_provider_connection)\
        .with({:service => 'volume', :tenant_name => nil}).and_yield(service)
      expect { @task.do_volume_creation_check([pending_volume_attrs]) }.to raise_error(MiqException::MiqProvisionError)
    end
  end
end
