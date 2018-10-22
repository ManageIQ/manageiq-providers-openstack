module ManageIQ::Providers::Openstack::IdentitySyncMixin
  IDENTITY_SYNC_ADMIN_ROLE_ID = "identity_sync_admin_role_id".freeze
  IDENTITY_SYNC_MEMBER_ROLE_ID = "identity_sync_member_role_id".freeze
  IDENTITY_SYNC_ADMIN_ROLE_ID_NEW = "identity_sync_admin_role_id_new".freeze
  IDENTITY_SYNC_MEMBER_ROLE_ID_NEW = "identity_sync_member_role_id_new".freeze

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
    ext_management_system.miq_custom_set(IDENTITY_SYNC_ADMIN_ROLE_ID_NEW, admin_role_id)
    ext_management_system.miq_custom_set(IDENTITY_SYNC_MEMBER_ROLE_ID_NEW, member_role_id)
    myusers = list_users
    _log.info("list_users: #{myusers}")
    myusers.each do |u|
      email = u["email"]
      username = u["name"]
      user_uuid = u["id"]
      enabled = u["enabled"]
      _log.info("user: #{username}")

      next if skip_user?(username) || enabled == false

      user = create_or_find_user(user_uuid, username, email, password_digest)
      # user is nil if an exist user exist with the same username but different email
      # in this case we don't do anything
      next if user.nil?

      sync_user_projects_and_roles(user, user_uuid)
    end
    ext_management_system.miq_custom_set(IDENTITY_SYNC_ADMIN_ROLE_ID, admin_role_id)
    ext_management_system.miq_custom_set(IDENTITY_SYNC_MEMBER_ROLE_ID, member_role_id)
  end

  def validate_and_sync_user_roles(project, user, user_uuid)
    project_name = project["name"]
    project_uuid = project["id"]
    _log.info("project: #{project_name}")

    # skip service tenant
    return if project_name == "service"

    cloud_tenant = CloudTenant.find_by(:name => project_name, :ems_id => id)
    return if cloud_tenant.nil?
    tenant = Tenant.find_by(:source_id => cloud_tenant.id, :source_type => 'CloudTenant')
    return if tenant.nil?

    sync_user_roles(user, user_uuid, tenant, project_uuid)
  end

  def sync_user_projects_and_roles(user, user_uuid)
    user_projects = keystone.list_user_projects_tenants(user_uuid)
    user_projects.each do |p|
      validate_and_sync_user_roles(p, user, user_uuid)
    end
  end

  def sync_user_roles(user, user_uuid, tenant, project_uuid)
    # Find roles that this user has for this project/tenant
    roles = keystone.list_project_tenant_user_roles(project_uuid, user_uuid)
    _log.info("roles: #{roles}")
    roles.each do |r|
      role_name = r["name"]
      create_or_find_miq_group_and_add_user(user, tenant, role_name)
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

  def remove_user_from_group(user, tenant, role_id)
    miq_group = MiqGroup.joins(:entitlement).where(:tenant_id => tenant.id).where('entitlements.miq_user_role_id' => role_id).take
    _log.info("removing user from group: #{miq_group.name}")
    miq_group&.users&.delete(user)
    miq_group&.save!
    if user.current_group == miq_group
      _log.info("setting current_group to nil: #{user.current_group.name}")
      user.current_group = nil
      user.save!
      _log.info("current_group after save: #{user.current_group}")
    end
  end

  def remove_from_previous_role_if_role_has_changed(existing_role_id, selected_role_id, user, tenant)
    existing_role_id = ext_management_system.miq_custom_get(existing_role_id)
    _log.info("existing role id: #{existing_role_id}") if existing_role_id
    unless existing_role_id.to_s == selected_role_id.to_s
      remove_user_from_group(user, tenant, existing_role_id) unless existing_role_id.nil?
    end
  end

  def create_or_find_miq_group_and_add_user(user, tenant, role_name)
    # Find MiqGroup corresponding to this role and project/tenant
    # create one if it doesn't exist
    # add user to the MiqGroup
    admin_role_id = ext_management_system.miq_custom_get(IDENTITY_SYNC_ADMIN_ROLE_ID_NEW)
    admin_role = MiqUserRole.find(admin_role_id)
    member_role_id = ext_management_system.miq_custom_get(IDENTITY_SYNC_MEMBER_ROLE_ID_NEW)
    user_role = MiqUserRole.find(member_role_id)

    this_role = nil
    if role_name == "admin"
      this_role = admin_role
      _log.info("selected admin_role: #{admin_role.name} id: #{admin_role.id}")
      remove_from_previous_role_if_role_has_changed(IDENTITY_SYNC_ADMIN_ROLE_ID, admin_role_id, user, tenant)
    elsif role_name == "_member_"
      this_role = user_role
      _log.info("new member_role: #{user_role.name} id: #{user_role.id}")
      remove_from_previous_role_if_role_has_changed(IDENTITY_SYNC_MEMBER_ROLE_ID, member_role_id, user, tenant)
    else
      return
    end

    _log.info("this_role: #{this_role.name} id: #{this_role.id}")

    if this_role
      miq_group = MiqGroup.joins(:entitlement).where(:tenant_id => tenant.id).where('entitlements.miq_user_role_id' => this_role.id).take
      _log.info("existing group id: #{miq_group.id} name: #{miq_group.name}") if miq_group
      if miq_group.nil?
        miq_group = MiqGroup.new
        miq_group.tenant = tenant

        entitlement = Entitlement.new
        entitlement.miq_user_role = this_role
        entitlement.miq_group = miq_group
        entitlement.save!

        miq_group.entitlement = entitlement
        miq_group.description = create_group_name(ext_management_system, tenant, this_role)
        unless miq_group.valid?
          description_errors = miq_group.errors[:description]
          if description_errors.size == 1 && description_errors[0].starts_with?("is not unique")
            # A group with this description already exists, probably because a user previously changed
            # the associated role. Create a timestamped description to ensure uniqueness
            miq_group.description = create_group_name(ext_management_system, tenant, this_role, true)
          end
        end
        miq_group.save!
        _log.info("new group id: #{miq_group.id} name: #{miq_group.name}")
      end

      unless miq_group.users.include?(user)
        miq_group.users << user
        miq_group.save!
      end
      unless user.current_group
        _log.info("setting current_group to: #{miq_group.name} from: #{user.current_group}")
        user.current_group = miq_group
        user.save!
        _log.info("current_group after save: #{user.current_group.name}")
      end
      miq_group
    end
  end

  def create_group_name(ems, tenant, role, timestamp = false)
    domain_id_component = ems.keystone_v3_domain_id.nil? ? "" : "-#{ems.keystone_v3_domain_id}"
    timestamp_component = timestamp ? "-#{Time.now.to_f}" : ""
    "#{ems.name}#{domain_id_component}-#{tenant.name}-#{role.name}#{timestamp_component}"
  end
end
