require 'manageiq/network_discovery/port'

module ManageIQ::Providers::Openstack
  class Discovery
    IRONIC_PORT = 6385

    def self.probe(ost)
      # Openstack InfraManager (TripleO/Director) discovery
      if ManageIQ::NetworkDiscovery::Port.open?(ost, IRONIC_PORT)
        res = ""
        Socket.tcp(ost.ipaddr, 6385) do |s|
          s.print("GET / HTTP/1.0\r\n\r\n")
          s.close_write
          res = s.read
        end
        ost.hypervisor << :openstack_infra if res =~ /OpenStack Ironic API/
      end
    end
  end
end
