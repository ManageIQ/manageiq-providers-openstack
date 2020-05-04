module OpenstackHandle
  class BaremetalDelegate < DelegateClass(Fog::Baremetal::OpenStack)
    include OpenstackHandle::HandledList
    include Vmdb::Logging

    SERVICE_NAME = "Baremetal"

    attr_reader :name

    def initialize(dobj, os_handle, name)
      super(dobj)
      @os_handle = os_handle
      @name      = name
      @proxy     = openstack_proxy.to_s if openstack_proxy
    end
  end
end
