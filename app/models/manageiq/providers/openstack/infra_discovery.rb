require 'manageiq/network_discovery/port_scanner'

module ManageIQ::Providers::Openstack
  class InfraDiscovery
    def self.probe(ost)
      res = ""
      if ManageIQ::NetworkDiscovery::PortScanner.portOpen(ost, 6385)
        Socket.tcp(ost.ipaddr, 6385) do |s|
          s.print("GET / HTTP/1.0\r\n\r\n")
          s.close_write
          res = s.read
        end
      end
      ost.hypervisor << :ospinfra if res =~ /OpenStack Ironic API/
    end
  end
end
