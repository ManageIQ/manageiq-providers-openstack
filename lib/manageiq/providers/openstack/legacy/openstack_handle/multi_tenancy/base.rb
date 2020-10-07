module OpenstackHandle
  module MultiTenancy
    class Base
      def initialize(service, os_handle, service_name, collection_type, options = {}, method = :all)
        @service            = service
        @os_handle          = os_handle
        @service_name       = service_name
        @collection_type    = collection_type
        @options            = options
        @method             = method

        @options[:proxy] ||= ManageIQ::Providers::Openstack::CloudManager.http_proxy_uri&.to_s
      end
    end
  end
end
