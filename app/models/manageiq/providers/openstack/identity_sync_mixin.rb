module ManageIQ::Providers::Openstack::IdentitySyncMixin
  def list_users
    # V2 requires adminURL as endpoint_type
    connection_options = {:service => "Identity", :openstack_endpoint_type => 'adminURL'}
    ext_management_system.with_provider_connection(connection_options) do |service|
      service.list_users.body["users"]
    end
  end

  def new_users
    users = []
    openstack_users = list_users
    openstack_users.each do |u|
      username = u["name"]
      user_uuid = u["id"]
      next if skip_user?(username)
      user_projects = keystone.list_user_projects_tenants(user_uuid)
      next unless user_projects.count.positive?
      user = User.find_by(:userid => username)
      users << u if user.nil?
    end
    users
  end

  def sync_users_queue(userid, admin_role_id, member_role_id, password_digest)
    task_opts = {
      :action => "Sync Users",
      :userid => userid
    }
    queue_opts = {
      :class_name  => self.class.name,
      :method_name => 'sync_users',
      :instance_id => id,
      :role        => 'ems_operations',
      :zone        => ext_management_system.my_zone,
      :args        => [admin_role_id, member_role_id, password_digest]
    }
    MiqTask.generic_action_with_callback(task_opts, queue_opts)
  end

  def sync_users(admin_role_id, member_role_id, password_digest)
    myusers = list_users
    myusers.each do |u|
      email = u["email"]
      username = u["name"]
      user_uuid = u["id"]
      enabled = u["enabled"]

      next if skip_user?(username) || enabled == false

      user = create_or_find_user(user_uuid, username, email, password_digest)
      # user is nil if an exist user exist with the same username but different email
      # in this case we don't do anything
      next if user.nil?

      user_projects = keystone.list_user_projects_tenants(user_uuid)
      user_projects.each do |p|
        project_name = p["name"]
        project_uuid = p["id"]

        # skip service tenant
        next if project_name == "service"

        cloud_tenant = CloudTenant.find_by(:name => project_name, :ems_id => id)
        next if cloud_tenant.nil?
        tenant = Tenant.find_by(:source_id => cloud_tenant.id, :source_type => 'CloudTenant')
        next if tenant.nil?

        # Find roles that this user has for this project/tenant
        roles = keystone.list_project_tenant_user_roles(project_uuid, user_uuid)
        roles.each do |r|
          role_name = r["name"]
          create_or_find_miq_group_and_add_user(user, tenant, role_name, admin_role_id, member_role_id)
        end
      end
    end
  end

  def keystone
    openstack_handle.identity_service
  end

  def skip_user?(username)
    users_to_skip = ['admin', 'neutron', 'heat', 'aodh', 'cinder', 'swift',
                     'glance', 'placement', 'gnocchi', 'nova', 'heat-cfn',
                     'panko', 'ceilometer', 'mistral', 'zaqar-websocket',
                     'ironic', 'ironic-inspector', 'zaqar']
    users_to_skip.include?(username)
  end

  def create_or_find_user(openstack_uuid, username, email, password_digest)
    user = User.find_by(:userid => username)
    if user
      # user already exist with this user name
      # if email doesn't match, then this record should be skipped
      user = nil if user.email != email
    elsif keystone.list_user_projects_tenants(openstack_uuid).count.zero?
      # don't create a new user if the user is not a member of
      # any tenants in OpenStack because the user's current_group
      # attribute will be nil and will not be able to login.
    else
      user = User.new
      user.name = username
      user.userid = username
      user.email = email
      if password_digest
        user.password_digest = password_digest
      else
        user.password = SecureRandom.urlsafe_base64(20)
      end
      user.settings[:openstack_user_id] = openstack_uuid
      user.save!
    end
    user
  end

  def create_or_find_miq_group_and_add_user(user, tenant, role_name, admin_role_id, member_role_id)
    # Find MiqGroup corresponding to this role and project/tenant
    # create one if it doesn't exist
    # add user to the MiqGroup
    admin_role = MiqUserRole.find(admin_role_id)
    user_role = MiqUserRole.find(member_role_id)

    this_role = nil
    if role_name == "admin"
      this_role = admin_role
    elsif role_name == "_member_"
      this_role = user_role
    else
      return
    end

    if this_role
      miq_group = MiqGroup.joins(:entitlement).where(:tenant_id => tenant.id).where('entitlements.miq_user_role_id' => this_role.id).take
      if miq_group.nil?
        miq_group = MiqGroup.new
        miq_group.tenant = tenant

        entitlement = Entitlement.new
        entitlement.miq_user_role = this_role
        entitlement.miq_group = miq_group
        entitlement.save!

        miq_group.entitlement = entitlement
        miq_group.description = create_group_name(ext_management_system, tenant, this_role)
        miq_group.save!
      end

      unless miq_group.users.include?(user)
        miq_group.users << user
        miq_group.save!
      end
      unless user.current_group
        user.current_group = miq_group
        user.save!
      end
      miq_group
    end
  end

  def create_group_name(ems, tenant, role)
    if ems.keystone_v3_domain_id.nil?
      "#{ems.name}-#{tenant.name}-#{role.name}"
    else
      "#{ems.name}-#{ems.keystone_v3_domain_id}-#{tenant.name}-#{role.name}"
    end
  end
end
