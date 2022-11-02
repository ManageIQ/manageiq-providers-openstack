FactoryBot.define do
  factory :cloud_network_openstack,
          :class  => "ManageIQ::Providers::Openstack::NetworkManager::CloudNetwork",
          :parent => :cloud_network

  factory :cloud_network_private_openstack,
          :class  => "ManageIQ::Providers::Openstack::NetworkManager::CloudNetwork::Private",
          :parent => :cloud_network_openstack

  factory :cloud_network_public_openstack,
          :class  => "ManageIQ::Providers::Openstack::NetworkManager::CloudNetwork::Public",
          :parent => :cloud_network_openstack
end
