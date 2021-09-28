module OpenstackHandle
  class WorkflowDelegate < DelegateClass(Fog::OpenStack::Workflow)
    include OpenstackHandle::HandledList
    include Vmdb::Logging

    SERVICE_NAME = "Workflow".freeze

    attr_reader :name

    def initialize(dobj, os_handle, name)
      super(dobj)
      @os_handle = os_handle
      @name      = name
      @proxy     = openstack_proxy if openstack_proxy
    end

    def execute_action(action, input)
      execute("create_action_execution", action, input)
    end

    def execute_workflow(workflow, input)
      execute("create_execution", workflow, input)
    end

    def has_workflow?(workflow_name)
      has_item?("get_workflow", workflow_name)
    end

    def has_action?(action_name)
      has_item?("get_action", action_name)
    end

    private

    def execute(service_method, item_name, input)
      response, state, execution_id = nil
      @os_handle.service_for_each_accessible_tenant(SERVICE_NAME) do |svc|
        response = svc.send(service_method, item_name, input)
        state = response.body["state"]
        execution_id = response.body["id"]

        while state == "RUNNING"
          sleep 5
          response = svc.get_execution(execution_id)
          state = response.body["state"]
        end
      end
      [execution_id, state, response]
    end

    def has_item?(service_method, item_name)
      result = false
      @os_handle.service_for_each_accessible_tenant(SERVICE_NAME) do |svc|
        begin
          response = svc.send(service_method, item_name)
          return true if response.status == 200
        rescue => err
          _log.info("MIQ(#{self}.#{__method__}) item #{item_name} not found: #{err}")
        end
      end
      result
    end
  end
end
