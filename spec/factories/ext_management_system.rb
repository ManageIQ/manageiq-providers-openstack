FactoryBot.define do
  factory :ems_openstack_cinder,
          :aliases => ["manageiq/providers/openstack/storage_manager/cinder_manager"],
          :class   => "ManageIQ::Providers::Openstack::StorageManager::CinderManager",
          :parent  => :ems_cinder do
    parent_manager :factory => :ems_openstack
  end
end
