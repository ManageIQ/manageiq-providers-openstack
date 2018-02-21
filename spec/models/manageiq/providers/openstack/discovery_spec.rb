describe ManageIQ::Providers::Openstack::Discovery do
  it ".probe" do
    require 'ostruct'
    allow(ManageIQ::NetworkDiscovery::Port).to receive(:open?).and_return(true)
    allow(Socket).to receive(:tcp).and_yield(double(:print => nil, :close_write => nil, :read => "OpenStack Ironic API"))
    ost = OpenStruct.new(:ipaddr => "172.168.0.1", :hypervisor => [])
    described_class.probe(ost)
    expect(ost.hypervisor).to eq [:openstack_infra]
  end
end
