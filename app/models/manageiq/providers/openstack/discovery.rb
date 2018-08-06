require 'manageiq/network_discovery/port'
require 'openssl'

module ManageIQ::Providers::Openstack
  class Discovery
    IRONIC_PORTS = [6385, 13_385].freeze

    def self.probe(ost)
      IRONIC_PORTS.each do |port|
        next unless ManageIQ::NetworkDiscovery::Port.open?(ost, port)
        response = tcp_request(ost.ipaddr, port, "GET / HTTP/1.0\r\n\r\n")
        ost.hypervisor << :openstack_infra if response =~ /OpenStack Ironic API/
      end
    end

    # Send SSL request first then plain TCP request if SSL fails
    def self.tcp_request(ipaddr, port, request)
      tcp_client = TCPSocket.new(ipaddr, port)
      ssl_context = OpenSSL::SSL::SSLContext.new
      ssl_client = OpenSSL::SSL::SSLSocket.new(tcp_client, ssl_context)
      ssl_client.sync_close = true
      ssl_client.connect
      ssl_client.syswrite(request)
      response = ssl_client.read
      ssl_client.close
      return response
    rescue OpenSSL::SSL::SSLError
      tcp_client = TCPSocket.new(ipaddr, port)
      tcp_client.syswrite(request)
      tcp_client.close_write
      response = tcp_client.read
      tcp_client.close
      return response
    end
  end
end
