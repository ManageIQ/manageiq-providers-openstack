describe ManageIQ::Providers::Openstack::CloudManager::Provision::Configuration do
  context "#configure_network_adapters" do
    before do
      @ems      = FactoryBot.create(:ems_openstack_with_authentication)
      @template = FactoryBot.create(:template_openstack, :ext_management_system => @ems)
      @vm       = FactoryBot.create(:vm_openstack)
      @net1     = FactoryBot.create(:cloud_network)
      @net2     = FactoryBot.create(:cloud_network)

      @task = FactoryBot.create(:miq_provision_openstack,
                                 :source      => @template,
                                 :destination => @vm,
                                 :state       => 'pending',
                                 :status      => 'Ok',
                                 :options     => {
                                   :src_vm_id     => @template.id,
                                   :cloud_network => [@net1.id, @net1.name]
                                 }
                                )
      allow(@task).to receive_messages(:miq_request => double("MiqRequest").as_null_object)
    end

    it "sets nic from dialog" do
      @task.configure_network_adapters

      expect(@task.options[:networks]).to eq([{"net_id" => @net1.ems_ref}])
    end

    it "sets nic from dialog with additional nic from automate" do
      @task.options[:networks] = [nil, {:network_id => @net2.id}]

      @task.configure_network_adapters

      expect(@task.options[:networks]).to eq([{"net_id" => @net1.ems_ref}, {"net_id" => @net2.ems_ref}])
    end

    it "override nic from dialog with nic from automate" do
      @task.options[:networks] = [{:network_id => @net2.id}]

      @task.configure_network_adapters

      expect(@task.options[:networks]).to eq([{"net_id" => @net2.ems_ref}])
    end

    it "ensure there are no blanks in the array" do
      @task.options[:networks] = [nil, nil, {:network_id => @net2.id}]

      @task.configure_network_adapters

      expect(@task.options[:networks]).to eq([{"net_id" => @net1.ems_ref}, {"net_id" => @net2.ems_ref}])
    end
  end
end
