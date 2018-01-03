# Change Log

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](http://keepachangelog.com/en/1.0.0/)


## Unreleased as of Sprint 76 ending 2018-01-01

### Fixed
- Fix Provisioning of disconnected VolumeTemplate [(#173)](https://github.com/ManageIQ/manageiq-providers-openstack/pull/173)

## Unreleased as of Sprint 75 ending 2017-12-11

### Fixed
- Added supported_catalog_types [(#177)](https://github.com/ManageIQ/manageiq-providers-openstack/pull/177)
- Skip disabled tenants when connecting to OpenStack [(#172)](https://github.com/ManageIQ/manageiq-providers-openstack/pull/172)
- Corrects handling of Notification params [(#171)](https://github.com/ManageIQ/manageiq-providers-openstack/pull/171)
- Set VolumeTemplate name to ID if empty [(#169)](https://github.com/ManageIQ/manageiq-providers-openstack/pull/169)
- Include HelperMethods instead of extending [(#167)](https://github.com/ManageIQ/manageiq-providers-openstack/pull/167)
- Don't pass nil ssl_options to try_connection [(#166)](https://github.com/ManageIQ/manageiq-providers-openstack/pull/166)
- Handle attempts to delete volumes that have already been deleted [(#147)](https://github.com/ManageIQ/manageiq-providers-openstack/pull/147)
- Replace conditions with scope [(#144)](https://github.com/ManageIQ/manageiq-providers-openstack/pull/144)

## Unreleased as of Sprint 74 ending 2017-11-27

### Fixed
- Add error message if FIP assigned to router [(#161)](https://github.com/ManageIQ/manageiq-providers-openstack/pull/161)
- safe_call should catch Fog::Errors::NotFound [(#156)](https://github.com/ManageIQ/manageiq-providers-openstack/pull/156)
- Don't attempt cloning of OpenStack infra templates [(#153)](https://github.com/ManageIQ/manageiq-providers-openstack/pull/153)
- Remove floating_ip_address from the create request if it is blank [(#145)](https://github.com/ManageIQ/manageiq-providers-openstack/pull/145)

## Unreleased as of Sprint 73 ending 2017-11-13

### Fixed
- Make sure volume template has name [(#148)](https://github.com/ManageIQ/manageiq-providers-openstack/pull/148)
- If an image name is "" use the image's id instead [(#146)](https://github.com/ManageIQ/manageiq-providers-openstack/pull/146)
- manageiq-gems-pending is already from manageiq itself [(#141)](https://github.com/ManageIQ/manageiq-providers-openstack/pull/141)

### Removed
- Remove old refresh settings [(#135)](https://github.com/ManageIQ/manageiq-providers-openstack/pull/135)

## Unreleased as of Sprint 72 ending 2017-10-30

### Added
- Adds vm_snapshot_success Notification creation [(#128)](https://github.com/ManageIQ/manageiq-providers-openstack/pull/128)
- Trim Volume error messages out of Fog responses [(#123)](https://github.com/ManageIQ/manageiq-providers-openstack/pull/123)
- Enable provisioning from Volumes and Volume Snapshots via a proxy type [(#104)](https://github.com/ManageIQ/manageiq-providers-openstack/pull/104)
- Orchestration Stack and Cloud Tenant targeted refresh [(#86)](https://github.com/ManageIQ/manageiq-providers-openstack/pull/86)
- Add notifications for VM destroy Cloud Volume and Cloud Volume Snapshot actions [(#85)](https://github.com/ManageIQ/manageiq-providers-openstack/pull/85)
- Trim error messages from fog responses for remaining models [(#130)](https://github.com/ManageIQ/manageiq-providers-openstack/pull/130)

### Fixed
- Translate exceptions from raw_connect [(#132)](https://github.com/ManageIQ/manageiq-providers-openstack/pull/132)
- Fix for amqp events [(#131)](https://github.com/ManageIQ/manageiq-providers-openstack/pull/131)
- Update event parser code to deal with amqp messages [(#127)](https://github.com/ManageIQ/manageiq-providers-openstack/pull/127)
- Trim key pair errors out of api responses [(#120)](https://github.com/ManageIQ/manageiq-providers-openstack/pull/120)
- Only update tenant mapping for the network manager if it's present [(#119)](https://github.com/ManageIQ/manageiq-providers-openstack/pull/119)
- Update raw connect method to accomodate OpenStack complexity [(#118)](https://github.com/ManageIQ/manageiq-providers-openstack/pull/118)
- Trim neutron error messages out of fog responses [(#110)](https://github.com/ManageIQ/manageiq-providers-openstack/pull/110) 

## Gaprindashvili Beta1

### Added
- Enhance orchestration template parameter type support [(#105)](https://github.com/ManageIQ/manageiq-providers-openstack/pull/105)
- Add update action for Image [(#102)](https://github.com/ManageIQ/manageiq-providers-openstack/pull/102)
- Update to infra refresher for OSP12 [(#99)](https://github.com/ManageIQ/manageiq-providers-openstack/pull/99)
- Change Compute service to Image in delete action [(#103)](https://github.com/ManageIQ/manageiq-providers-openstack/pull/103)
- Add create action for Image [(#89)](https://github.com/ManageIQ/manageiq-providers-openstack/pull/89)
- Fix collector caching and improve collection of network relations for targeted refresh [(#82)](https://github.com/ManageIQ/manageiq-providers-openstack/pull/82)
- Add class for parsing refresh targets from EmsEvents [(#81)](https://github.com/ManageIQ/manageiq-providers-openstack/pull/81)
- Add cloud volume restore and delete raw actions. Cloud volume backup [(#83)](https://github.com/ManageIQ/manageiq-providers-openstack/pull/83)
- Add vm security group operations [(#79)](https://github.com/ManageIQ/manageiq-providers-openstack/pull/79)
- Add scale_down and scale_up tasks to OrchestrationStack [(#55)](https://github.com/ManageIQ/manageiq-providers-openstack/pull/55)
- Targeted Refresh for Cloud VMs [(#74)](https://github.com/ManageIQ/manageiq-providers-openstack/pull/74)
- Adds specific methods for creating, deleting flavors. [(#65)](https://github.com/ManageIQ/manageiq-providers-openstack/pull/65)

### Fixed
- Filter out resources with blank physical_resource_id [(#113)](https://github.com/ManageIQ/manageiq-providers-openstack/pull/113)
- Fix attach/detach disks automate methods [(#112)](https://github.com/ManageIQ/manageiq-providers-openstack/pull/112)
- Trim error messages out of cloud tenant fog responses [(#111)](https://github.com/ManageIQ/manageiq-providers-openstack/pull/111)
- Use floating_ip_address instead of name for creation messages [(#109)](https://github.com/ManageIQ/manageiq-providers-openstack/pull/109)
- Event parser sets host id [(#108)](https://github.com/ManageIQ/manageiq-providers-openstack/pull/108)
- Check provisioning status with the correct tenant scoping [(#97)](https://github.com/ManageIQ/manageiq-providers-openstack/pull/97)
- Add flavors info in instance provisioning [(#91)](https://github.com/ManageIQ/manageiq-providers-openstack/pull/91)
- Old Refresh: Don't error out if a port refers to an unknown subnet. [(#90)](https://github.com/ManageIQ/manageiq-providers-openstack/pull/90)
- Reading mac from the reported port correctly [(#87)](https://github.com/ManageIQ/manageiq-providers-openstack/pull/87)
- Update miq-module dependency to more_core_extensions [(#77)](https://github.com/ManageIQ/manageiq-providers-openstack/pull/77)
- Update provision requirements check to allow exact matches [(#72)](https://github.com/ManageIQ/manageiq-providers-openstack/pull/72)
- Handle case where do_volume_creation_check gets a nil from Fog [(#73)](https://github.com/ManageIQ/manageiq-providers-openstack/pull/73)
- Assign only compact and unique list of hosts [(#71)](https://github.com/ManageIQ/manageiq-providers-openstack/pull/71)

### Removed
- Remove old refresh settings [(#135)](https://github.com/ManageIQ/manageiq-providers-openstack/pull/135)

## Initial changelog added
