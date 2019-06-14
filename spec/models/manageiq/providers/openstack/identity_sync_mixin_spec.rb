describe ManageIQ::Providers::Openstack::IdentitySyncMixin do
  let(:ems) { FactoryBot.create(:ems_openstack_with_authentication) }
  let(:parent_tenant) { FactoryBot.create(:tenant, :source_type => "ExtManagementSystem", :source_id => ems.id) }

  before do
    keystone = instance_double("keystone")
    allow(ems).to receive(:keystone).and_return(keystone)
    user_projects_data = [{"description" => nil, "enabled" => true, "id" => "6f4a2d27d0454ec1a100109b38cbfa09", "name" => "project1"}]
    allow(ems.keystone).to receive(:list_user_projects_tenants).and_return(user_projects_data)
    parent_tenant.save!
  end

  context "sync_users" do
    it "should create user, groups, and assign user to group" do
      list_users_data = [{"name" => "project1-admin", "domain_id" => "default", "enabled" => true, "options" => {}, "id" => "0dab7200c18945f0ad96abdcfcc59716", "email" => "project1-admin@localhost", "password_expires_at" => nil}]
      allow(ems).to receive(:list_users).and_return(list_users_data)
      user_projects_data = [{"description" => nil, "enabled" => true, "id" => "6f4a2d27d0454ec1a100109b38cbfa09", "name" => "project1"}]
      allow(ems.keystone).to receive(:list_user_projects_tenants).and_return(user_projects_data)
      expect(User.find_by(:userid => "project1-admin")).to be_nil
      cloud_tenant = FactoryBot.create(:cloud_tenant_openstack, :name => 'project1', :ems_id => ems.id)
      tenant = FactoryBot.create(:tenant, :source_id => cloud_tenant.id, :source_type => 'CloudTenant')
      expect(CloudTenant.find_by(:name => 'project1', :ems_id => ems.id)).not_to be_nil
      expect(Tenant.find_by(:source_id => cloud_tenant.id, :source_type => 'CloudTenant')).not_to be_nil
      user_roles = [{"domain_id" => nil, "name" => "admin", "id" => "4e918d9808d34e658a3a647ed49b53f5"}, {"domain_id" => nil, "name" => "_member_", "id" => "9fe2ff9ee4384b1894a90878d3e92bab"}]
      allow(ems.keystone).to receive(:list_project_tenant_user_roles).and_return(user_roles)
      admin_role = FactoryBot.create(:miq_user_role, :name => "EvmRole-tenant_administrator")
      member_role = FactoryBot.create(:miq_user_role, :name => "EvmRole-user")

      ems.sync_users(admin_role.id, member_role.id, "changeme")
      user = User.find_by(:userid => "project1-admin")
      expect(user).not_to be_nil
      expect(user.password_digest).not_to be_nil
      # current_group is required or user will not be able to login even if they have a password
      expect(user.current_group.miq_user_role).to eq(admin_role)
      expect(user.current_group.tenant).to eq(tenant)
      expect(user.miq_groups.count).to eq(2)

      # running sync_users multiple times should not create additional users if there are no changes
      # in OpenStack
      user_count = User.count
      ems.sync_users(admin_role.id, member_role.id, "changeme")
      expect(User.count).to eq(user_count)
      user = User.find_by(:userid => "project1-admin")
      expect(user.current_group.miq_user_role).to eq(admin_role)
      expect(user.current_group.tenant).to eq(tenant)
      expect(user.miq_groups.count).to eq(2)

      # switch roles in sync should unmap user from old groups and roles
      user = User.find_by(:userid => "project1-admin")
      expect(user.current_group.miq_user_role.id).to eq(admin_role.id)
      new_admin_role = FactoryBot.create(:miq_user_role, :name => "EvmRole-operator")
      new_member_role = FactoryBot.create(:miq_user_role, :name => "EvmRole-vm_user")
      ems.sync_users(new_admin_role.id, new_member_role.id, "changeme")
      user = User.find_by(:userid => "project1-admin")
      expect(user.miq_groups.count).to eq(2)
      user.miq_groups.each do |group|
        expect(group.miq_user_role).not_to eq(admin_role)
        expect(group.miq_user_role).not_to eq(member_role)
      end
      expect(user.current_group.miq_user_role.id.to_s).not_to eq(admin_role.id.to_s)
      expect(user.current_group.miq_user_role.id.to_s).not_to eq(member_role.id.to_s)
      expect(user.current_group.miq_user_role.id.to_s).to eq(new_admin_role.id.to_s)
    end

    it "should create realuser, but skip admin and other special cases" do
      list_users_data = [{"name" => "admin", "domain_id" => "default", "enabled" => true, "options" => {}, "id" => "009cfe67e1984e4dae36af5625c2fe92", "email" => "admin@localhost", "password_expires_at" => nil}, {"name" => "realuser", "domain_id" => "default", "enabled" => true, "options" => {}, "id" => "0dab7200c18945f0ad96abdcfcc59716", "email" => "realuser@localhost", "password_expires_at" => nil}]
      allow(ems).to receive(:list_users).and_return(list_users_data)
      expect(User.find_by(:userid => "admin")).to be_nil
      expect(User.find_by(:userid => "realuser")).to be_nil
      ems.sync_users(1, 1, "changeme")
      expect(User.find_by(:userid => "admin")).to be_nil
      expect(User.find_by(:userid => "realuser")).not_to be_nil
    end
  end

  context "create_or_find_user" do
    it "should create a new user if it doesn't already exist" do
      username = "project1-admin"
      email = "testuser1@server.org"
      password = "changeme"
      user = User.find_by(:userid => username)
      expect(user).to be_nil
      user = ems.create_or_find_user(101, username, email, password)
      expect(user.name).to eq(username)
      expect(user.email).to eq(email)
    end

    it "should only return an existing user if username and email match" do
      user = ems.create_or_find_user(1, "testuser", "testuser@email.com", "changeme")
      expect(user).to_not be_nil
      user2 = ems.create_or_find_user(1, "testuser", "testuser@different.email.com", "changeme")
      expect(user2).to be_nil
    end

    it "should not create a new user if the user is not a member of any tenants" do
      # Such user would not be able to login because its current_group will be nil
      allow(ems.keystone).to receive(:list_user_projects_tenants).and_return([])
      user = ems.create_or_find_user(1, "userwithoutatenant", "userwithoutatenant@email.com", "changeme")
      expect(user).to be_nil
    end
  end

  context "create_or_find_miq_group_add_user" do
    it "should create new group and add user as member" do
      user = ems.create_or_find_user(101, "dummy_user1", "dummy1@test.com", "changeme")
      tenant = FactoryBot.create(:tenant, :name => "project1")

      admin_role = FactoryBot.create(:miq_user_role, :name => "EvmRole-tenant_administrator")
      member_role = FactoryBot.create(:miq_user_role, :name => "EvmRole-user")

      # admin
      miq_group = MiqGroup.joins(:entitlement).where(:tenant_id => tenant.id).where('entitlements.miq_user_role_id' => admin_role.id).take
      expect(miq_group).to be_nil
      ems.miq_custom_set(ManageIQ::Providers::Openstack::IdentitySyncMixin::IDENTITY_SYNC_ADMIN_ROLE_ID_NEW, admin_role.id)
      ems.miq_custom_set(ManageIQ::Providers::Openstack::IdentitySyncMixin::IDENTITY_SYNC_MEMBER_ROLE_ID_NEW, member_role.id)
      miq_group = ems.create_or_find_miq_group_and_add_user(user, tenant, "admin")

      expect(miq_group.tenant).to eq(tenant)
      expect(miq_group.entitlement.miq_user_role).to eq(admin_role)
      expect(miq_group.users.exists?(user.id)).to be true

      # member
      miq_group = MiqGroup.joins(:entitlement).where(:tenant_id => tenant.id).where('entitlements.miq_user_role_id' => member_role.id).take
      expect(miq_group).to be_nil
      miq_group = ems.create_or_find_miq_group_and_add_user(user, tenant, "_member_")

      expect(miq_group.tenant).to eq(tenant)
      expect(miq_group.entitlement.miq_user_role).to eq(member_role)
      expect(miq_group.users.exists?(user.id)).to be true
    end

    it "group should be named <provider>-<domainID>-<tenant>-<role> for keystone v3" do
      user = ems.create_or_find_user(101, "dummy_user1", "dummy1@test.com", "changeme")
      ems.keystone_v3_domain_id = "domain_id1"
      tenant = FactoryBot.create(:tenant, :name => "project1")
      admin_role = FactoryBot.create(:miq_user_role, :name => "EvmRole-tenant_administrator")
      member_role = FactoryBot.create(:miq_user_role, :name => "EvmRole-user")
      ems.miq_custom_set(ManageIQ::Providers::Openstack::IdentitySyncMixin::IDENTITY_SYNC_ADMIN_ROLE_ID_NEW, admin_role.id)
      ems.miq_custom_set(ManageIQ::Providers::Openstack::IdentitySyncMixin::IDENTITY_SYNC_MEMBER_ROLE_ID_NEW, member_role.id)
      miq_group = ems.create_or_find_miq_group_and_add_user(user, tenant, "admin")
      expect(miq_group.name).to eq("#{ems.name}-#{ems.keystone_v3_domain_id}-#{tenant.name}-#{admin_role.name}")
    end

    it "group should be named <provider-<tenant>-<role> for keystone v2" do
      user = ems.create_or_find_user(101, "dummy_user1", "dummy1@test.com", "changeme")
      tenant = FactoryBot.create(:tenant, :name => "project1")
      admin_role = FactoryBot.create(:miq_user_role, :name => "EvmRole-tenant_administrator")
      member_role = FactoryBot.create(:miq_user_role, :name => "EvmRole-user")
      ems.miq_custom_set(ManageIQ::Providers::Openstack::IdentitySyncMixin::IDENTITY_SYNC_ADMIN_ROLE_ID_NEW, admin_role.id)
      ems.miq_custom_set(ManageIQ::Providers::Openstack::IdentitySyncMixin::IDENTITY_SYNC_MEMBER_ROLE_ID_NEW, member_role.id)
      miq_group = ems.create_or_find_miq_group_and_add_user(user, tenant, "admin")
      expect(miq_group.name).to eq("#{ems.name}-#{tenant.name}-#{admin_role.name}")
    end

    # TODO: requires storing the selected roles in the provider model
    it "should remove group membership if user is removed from project in OpenStack" do
    end
  end

  context "new_users" do
    let(:ems) { FactoryBot.create(:ems_openstack_with_authentication) }

    it "finds new users from keystone" do
      users_data = [{"name" => "newuser1", "links" => {"self" =>" http://127.0.0.1:5002/v3/users/009cfe67e1984e4dae36af5625c2fe92"}, "domain_id" => "default", "enabled" => true, "options" => {}, "id" => "009cfe67e1984e4dae36af5625c2fe92", "email" => "newuser1@localhost", "password_expires_at" => nil}, {"name" => "newuser2", "links" => {"self" => "http://127.0.0.1:5002/v3/users/0dab7200c18945f0ad96abdcfcc59716"}, "domain_id" => "default", "enabled" => true, "options" => {}, "id" => "0dab7200c18945f0ad96abdcfcc59716", "email" => "newuser2@localhost", "password_expires_at" => nil}]
      allow(ems).to receive(:list_users).and_return(users_data)
      users = ems.new_users
      expect(users.count).to eq(2)
    end

    it "should skip special users like admin" do
      users_data = [{"name" => "admin", "links" => {"self" => "http://127.0.0.1:5002/v3/users/009cfe67e1984e4dae36af5625c2fe92"}, "domain_id" => "default", "enabled" => true, "options" => {}, "id" => "009cfe67e1984e4dae36af5625c2fe92", "email" => "admin@localhost", "password_expires_at" => nil}, {"name" => "ceilometer", "links" => {"self" => "http://127.0.0.1:5002/v3/users/0dab7200c18945f0ad96abdcfcc59716"}, "domain_id" => "default", "enabled" => true, "options" => {}, "id" => "0dab7200c18945f0ad96abdcfcc59716", "email" => "ceilometer@localhost", "password_expires_at" => nil}]
      allow(ems).to receive(:list_users).and_return(users_data)
      users = ems.new_users
      expect(users.count).to eq(0)
    end

    it "should not return users who are not member of any tenant" do
      users_data = [{"name" => "newuser1", "links" => {"self" =>" http://127.0.0.1:5002/v3/users/009cfe67e1984e4dae36af5625c2fe92"}, "domain_id" => "default", "enabled" => true, "options" => {}, "id" => "009cfe67e1984e4dae36af5625c2fe92", "email" => "newuser1@localhost", "password_expires_at" => nil}, {"name" => "userwithoutatenant", "links" => {"self" => "http://127.0.0.1:5002/v3/users/0dab7200c18945f0ad96abdcfcc59716"}, "domain_id" => "default", "enabled" => true, "options" => {}, "id" => "0dab7200c18945f0ad96abdcfcc59716", "email" => "userwithoutatenant@localhost", "password_expires_at" => nil}]
      allow(ems).to receive(:list_users).and_return(users_data)
      user_projects_data = [{"description" => nil, "enabled" => true, "id" => "6f4a2d27d0454ec1a100109b38cbfa09", "name" => "project1"}]
      allow(ems.keystone).to receive(:list_user_projects_tenants).with("009cfe67e1984e4dae36af5625c2fe92").and_return(user_projects_data)
      allow(ems.keystone).to receive(:list_user_projects_tenants).with("0dab7200c18945f0ad96abdcfcc59716").and_return([])
      users = ems.new_users
      expect(users.count).to eq(1)
    end
  end
end
