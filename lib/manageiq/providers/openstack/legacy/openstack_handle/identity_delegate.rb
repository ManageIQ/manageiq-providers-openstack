module OpenstackHandle
  class IdentityDelegate < DelegateClass(Fog::OpenStack::Identity)
    include OpenstackHandle::HandledList
    include Vmdb::Logging

    SERVICE_NAME = "Identity"

    attr_reader :name

    def initialize(dobj, os_handle, name)
      super(dobj)
      @os_handle = os_handle
      @name      = name
      @proxy     = openstack_proxy if openstack_proxy
    end

    def visible_tenants
      if respond_to?(:projects)
        # Check if keystone v3 method projects is available, if not fall back to v2
        visible_tenants_v3
      else
        visible_tenants_v2
      end
    end

    def visible_tenants_v3
      # Huge inconsistency in Keystone v3, we actually need to provide domain_id both in token and query param, but only
      # for keystone. This rule is defined in policy.json
      projects.all(:domain_id => @os_handle.domain_id, :user_id => current_user_id)
    end

    #
    # Services returned by Fog keystone v2 are always scoped.
    # For non-admin users, we must use an unscoped token to
    # retrieve a list of tenants the user can access.
    #
    def visible_tenants_v2
      response = Handle.try_connection(@os_handle.security_protocol) do |scheme, connection_options|
        url = Handle.auth_url(@os_handle.address, @os_handle.port, scheme, "/v2.0/tenants")
        connection = Fog::Core::Connection.new(url, false, connection_options)
        response = connection.request(
          :expects => [200, 204],
          :headers => {'Content-Type' => 'application/json',
                       'Accept'       => 'application/json',
                       'X-Auth-Token' => unscoped_token},
          :method  => 'GET'
        )
      end
      body = Fog::JSON.decode(response.body)
      vtenants = Fog::OpenStack::Identity::V2::Tenants.new
      vtenants.load(body['tenants'])
      vtenants
    end

    def create_tenant(options)
      if respond_to?(:projects)
        # Check if keystone v3 method projects is available, if not fall back to v2
        create_tenant_v3(options)
      else
        create_tenant_v2(options)
      end
    end

    def create_tenant_v3(options)
      project = projects.create({:domain_id => @os_handle.domain_id}.merge(options))
      admin_role = roles.all.detect { |x| x.name == 'admin' }
      user = users.all(:domain_id => @os_handle.domain_id).detect { |x| x.name == @os_handle.username }
      project.grant_role_to_user(admin_role.id, user.id)
      project
    end

    def create_tenant_v2(options)
      tenant = tenants.create(options)
      admin_role = roles.all.detect { |x| x.name == 'admin' }
      user = users.all.detect { |x| x.name == @os_handle.username }
      tenant.grant_user_role(user.id, admin_role.id)
      tenant
    end

    def update_tenant(tenant_id, options)
      if respond_to?(:projects)
        # Check if keystone v3 method projects is available, if not fall back to v2
        update_tenant_v3(tenant_id, options)
      else
        update_tenant_v2(tenant_id, options)
      end
    end

    def update_tenant_v3(tenant_id, options)
      project = projects.all(:domain_id => @os_handle.domain_id,
                             :user_id => current_user_id).detect {
        |x| x.id == tenant_id
      }
      project.update(options)
    end

    def update_tenant_v2(tenant_id, options)
      tenant = tenants.find_by_id(tenant_id)
      tenant.update(options)
    end

    def delete_tenant(tenant_id)
      if respond_to?(:projects)
        # Check if keystone v3 method projects is available, if not fall back to v2
        delete_tenant_v3(tenant_id)
      else
        delete_tenant_v2(tenant_id)
      end
    end

    def delete_tenant_v3(tenant_id)
      project = projects.all(:domain_id => @os_handle.domain_id,
                             :user_id => current_user_id).detect {
        |x| x.id == tenant_id
      }
      project.destroy
    end

    def delete_tenant_v2(tenant_id)
      tenants.destroy(tenant_id)
    end

    def list_user_projects_tenants(user_id)
      if respond_to?(:projects)
        # V3
        # filter projects by domain_id to ensure having projects only from domain_id entered in Provider form
        list_user_projects(user_id).body['projects'].select { |project| project['domain_id'] == @os_handle.domain_id }
      else
        # V2
        user_projects = []
        list_tenants.body['tenants'].each do |tenant|
          if list_roles_for_user_on_tenant(tenant['id'], user_id).body['roles'].count.positive?
            user_projects << tenant
          end
        end
        user_projects
      end
    end

    def list_project_tenant_user_roles(project_id, user_id)
      if respond_to?(:projects)
        # V3
        list_project_user_roles(project_id, user_id).body["roles"]
      else
        # V2
        list_roles_for_user_on_tenant(project_id, user_id).body["roles"]
      end
    end

    # Remove this method once fog/openstack allows get_project correctly
    def projects_get_by_id(id)
      @all_projects ||= projects.all
      @all_projects.find { |project| project.id == id }
    end
  end
end
