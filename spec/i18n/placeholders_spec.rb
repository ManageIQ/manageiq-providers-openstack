describe :placeholders do
  include_examples :placeholders, ManageIQ::Providers::Openstack::Engine.root.join('locale').to_s
end
