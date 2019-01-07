describe ManageIQ::Providers::Openstack::CloudManager::CloudTenant do
  let(:ems) { FactoryBot.create(:ems_openstack) }
  let(:tenant) { FactoryBot.create(:cloud_tenant_openstack, :ext_management_system => ems) }

  describe 'tenant methods' do
    context ".default_security_group" do
      it 'returns the security group named "default" if it exists' do
        test01 = FactoryBot.create(:security_group_openstack,
                                    :name         => 'test_1',
                                    :ems_ref      => 'one_id',
                                    :cloud_tenant => tenant)
        test02 = FactoryBot.create(:security_group_openstack,
                                    :name         => 'test_2',
                                    :ems_ref      => 'two_id',
                                    :cloud_tenant => tenant)
        default = FactoryBot.create(:security_group_openstack,
                                     :name         => 'default',
                                     :ems_ref      => 'default_id',
                                     :cloud_tenant => tenant)
        # Go through the convoluted effort of assigning a VM to
        # one of the security groups.
        # The 'default' security group should be returned
        # despite not having the most vms
        vm = FactoryBot.create(:vm_openstack)
        network_port = FactoryBot.create(:network_port_openstack)
        network_port.device = vm
        network_port.save
        network_port_security_group = NetworkPortSecurityGroup.new
        network_port_security_group.network_port_id = network_port.id
        network_port_security_group.security_group_id = test02.id
        network_port_security_group.save

        expect(tenant.default_security_group).to eq default
      end

      it 'returns the most populated security group if there is no default' do
        test01 = FactoryBot.create(:security_group_openstack,
                                    :name         => 'test_1',
                                    :ems_ref      => 'one_id',
                                    :cloud_tenant => tenant)
        test02 = FactoryBot.create(:security_group_openstack,
                                    :name         => 'test_2',
                                    :ems_ref      => 'two_id',
                                    :cloud_tenant => tenant)
        test03 = FactoryBot.create(:security_group_openstack,
                                    :name         => 'test_3',
                                    :ems_ref      => 'three_id',
                                    :cloud_tenant => tenant)
        # Go through the convoluted effort of assigning a VM to
        # one of the security groups.
        # The security group with the VM is the one that should be returned
        vm = FactoryBot.create(:vm_openstack)
        network_port = FactoryBot.create(:network_port_openstack)
        network_port.device = vm
        network_port.save
        network_port_security_group = NetworkPortSecurityGroup.new
        network_port_security_group.network_port_id = network_port.id
        network_port_security_group.security_group_id = test02.id
        network_port_security_group.save

        expect(tenant.default_security_group).to eq test02
      end

      it 'returns nil if there are no security groups' do
        expect(tenant.default_security_group).to eq nil
      end
    end
  end
end
