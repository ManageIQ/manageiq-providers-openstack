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

        proxy = VMDB::Util.http_proxy_uri(:openstack) || VMDB::Util.http_proxy_uri(:default)
        @options[:proxy] ||= proxy.to_s if proxy
      end
    end
  end
end
