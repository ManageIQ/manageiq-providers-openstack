describe ManageIQ::Providers::Openstack::IdentitySyncMixin do
  let(:ems) { FactoryGirl.create(:ems_openstack_with_authentication) }
  let(:parent_tenant) { FactoryGirl.create(:tenant, :source_type => "ExtManagementSystem", :source_id => ems.id) }

  before do
    keystone = instance_double("keystone")
    allow(ems).to receive(:keystone).and_return(keystone)
    parent_tenant.save!
  end

  context "sync_users" do
    it "should create realuser, but skip admin and other special cases" do
      list_users_data = [{"name" => "admin", "domain_id" => "default", "enabled" => true, "options" => {}, "id" => "009cfe67e1984e4dae36af5625c2fe92", "email" => "admin@localhost", "password_expires_at" => nil}, {"name" => "realuser", "domain_id" => "default", "enabled" => true, "options" => {}, "id" => "0dab7200c18945f0ad96abdcfcc59716", "email" => "realuser@localhost", "password_expires_at" => nil}]
      allow(ems).to receive(:list_users).and_return(list_users_data)
      allow(ems.keystone).to receive(:list_user_projects_tenants).and_return([])
      expect(User.find_by(:userid => "admin")).to be_nil
      expect(User.find_by(:userid => "realuser")).to be_nil
      ems.sync_users(1, 1)
      expect(User.find_by(:userid => "admin")).to be_nil
      expect(User.find_by(:userid => "realuser")).not_to be_nil
    end
  end

  context "create_or_find_user" do
    it "should create a new user if it doesn't already exist" do
      username = "project1-admin"
      email = "testuser1@server.org"
      user = User.find_by(:userid => username)
      expect(user).to be_nil
      user = ems.create_or_find_user(101, username, email)
      expect(user.name).to eq(username)
      expect(user.email).to eq(email)
    end

    it "should only return an existing user if username and email match" do
      user = ems.create_or_find_user(1, "testuser", "testuser@email.com")
      expect(user).to_not be_nil
      user2 = ems.create_or_find_user(1, "testuser", "testuser@different.email.com")
      expect(user2).to be_nil
    end
  end

  # context "create_or_find_tenant" do
  #  it "create_or_find_tenant" do
  #    project_name = "project1"
  #    ctenant = CloudTenant.where(name: project_name).where(ems_id: ems.id).take
  #    expect(ctenant).to be_nil
  #    tenant_before_count = Tenant.count
  #    tenant = ems.create_or_find_tenant(101, project_name, true)
  #    expect(Tenant.count).to eq(tenant_before_count + 1)
  #
  #    expect(tenant.name).to eq(project_name)
  #    expect(tenant.description).to eq(project_name)
  #    expect(tenant.source_type).to eq("CloudTenant")
  #    expect(tenant.parent).to eq(parent_tenant)
  #    expect(tenant.default_miq_group_id).not_to eq(0)

  #    ctenant = CloudTenant.where(name: project_name).where(ems_id: ems.id).take
  #    expect(tenant.source_id).to eq(ctenant.id)
  #    expect(ctenant.name).to eq(project_name)
  #    expect(ctenant.ext_management_system).to eq(ems)
  #    expect(ctenant.type).to eq("ManageIQ::Providers::Openstack::CloudManager::CloudTenant")
  #    expect(ctenant.enabled).to eq(true)

  #    # invoking second time should return existing tenant
  #    tenant = ems.create_or_find_tenant(101, project_name, true)
  #    expect(Tenant.count).to eq(tenant_before_count + 1)
  #    expect(tenant.name).to eq(project_name)
  #  end
  # end

  context "create_or_find_miq_group_add_user" do
    it "should create new group and add user as member" do
      user = ems.create_or_find_user(101, "dummy_user1", "dummy1@test.com")
      # leave in case we need to enable create_or_find_tenant
      # tenant = ems.create_or_find_tenant(101, "project1", true)
      tenant = FactoryGirl.create(:tenant, :name => "project1")

      admin_role = FactoryGirl.create(:miq_user_role, :name => "EvmRole-tenant_administrator")
      member_role = FactoryGirl.create(:miq_user_role, :name => "EvmRole-user")

      # admin
      miq_group = MiqGroup.joins(:entitlement).where(:tenant_id => tenant.id).where('entitlements.miq_user_role_id' => admin_role.id).take
      expect(miq_group).to be_nil
      miq_group = ems.create_or_find_miq_group_and_add_user(user, tenant, "admin", admin_role.id, member_role.id)

      expect(miq_group.tenant).to eq(tenant)
      expect(miq_group.entitlement.miq_user_role).to eq(admin_role)
      expect(miq_group.users.exists?(user)).to be true

      # member
      miq_group = MiqGroup.joins(:entitlement).where(:tenant_id => tenant.id).where('entitlements.miq_user_role_id' => member_role.id).take
      expect(miq_group).to be_nil
      miq_group = ems.create_or_find_miq_group_and_add_user(user, tenant, "_member_", admin_role.id, member_role.id)

      expect(miq_group.tenant).to eq(tenant)
      expect(miq_group.entitlement.miq_user_role).to eq(member_role)
      expect(miq_group.users.exists?(user)).to be true
    end

    it "group should be named <provider>-<domainID>-<tenant>-<role> for keystone v3" do
      user = ems.create_or_find_user(101, "dummy_user1", "dummy1@test.com")
      ems.keystone_v3_domain_id = "domain_id1"
      tenant = FactoryGirl.create(:tenant, :name => "project1")
      admin_role = FactoryGirl.create(:miq_user_role, :name => "EvmRole-tenant_administrator")
      member_role = FactoryGirl.create(:miq_user_role, :name => "EvmRole-user")
      miq_group = ems.create_or_find_miq_group_and_add_user(user, tenant, "admin", admin_role.id, member_role.id)
      expect(miq_group.name).to eq("#{ems.name}-#{ems.keystone_v3_domain_id}-#{tenant.name}-#{admin_role.name}")
    end

    it "group should be named <provider-<tenant>-<role> for keystone v2" do
      user = ems.create_or_find_user(101, "dummy_user1", "dummy1@test.com")
      tenant = FactoryGirl.create(:tenant, :name => "project1")
      admin_role = FactoryGirl.create(:miq_user_role, :name => "EvmRole-tenant_administrator")
      member_role = FactoryGirl.create(:miq_user_role, :name => "EvmRole-user")
      miq_group = ems.create_or_find_miq_group_and_add_user(user, tenant, "admin", admin_role.id, member_role.id)
      expect(miq_group.name).to eq("#{ems.name}-#{tenant.name}-#{admin_role.name}")
    end

    # TODO: requires storing the selected roles in the provider model
    it "should remove group membership if user is removed from project in OpenStack" do
    end
  end

  context "new_users" do
    let(:ems) { FactoryGirl.create(:ems_openstack_with_authentication) }

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
  end
end
