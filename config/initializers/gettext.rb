Vmdb::Gettext::Domains.add_domain(
  'ManageIQ_Providers_Openstack',
  ManageIQ::Providers::Openstack::Engine.root.join('locale').to_s,
  :po
)
