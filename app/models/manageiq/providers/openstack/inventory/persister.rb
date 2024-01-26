class ManageIQ::Providers::Openstack::Inventory::Persister < ManageIQ::Providers::Inventory::Persister
  # TODO(lsmola) figure out a way to pass collector info, probably via target, then remove the below
  attr_reader :collector

  # @param manager [ManageIQ::Providers::BaseManager] A manager object
  # @param target [Object] A refresh Target object
  # @param collector [ManageIQ::Providers::Inventory::Collector] A Collector object
  def initialize(manager, target = nil, collector = nil)
    @manager   = manager
    @target    = target
    @collector = collector

    @collections = {}

    initialize_inventory_collections
  end

  def cinder_manager
    manager.kind_of?(ManageIQ::Providers::Openstack::StorageManager::CinderManager) ? manager : manager.cinder_manager
  end

  def swift_manager
    manager.kind_of?(ManageIQ::Providers::Openstack::StorageManager::SwiftManager) ? manager : manager.swift_manager
  end
end
