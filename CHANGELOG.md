# Change Log

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](http://keepachangelog.com/en/1.0.0/)


## Unreleased as of Sprint 83 ending 2018-04-09

### Added
- Update VCRs and remove obsolete VCRs for very old versions of Openstack [(#266)](https://github.com/ManageIQ/manageiq-providers-openstack/pull/266)

### Fixed
- Avoid tenant discovery recursion [(#265)](https://github.com/ManageIQ/manageiq-providers-openstack/pull/265)
- Fallback to generic error parsing if neutron-specific parsing fails [(#263)](https://github.com/ManageIQ/manageiq-providers-openstack/pull/263)
- Fix parent subnet relationship [(#260)](https://github.com/ManageIQ/manageiq-providers-openstack/pull/260)
- Parse volume attachment/detachment messages from fog responses [(#253)](https://github.com/ManageIQ/manageiq-providers-openstack/pull/253)
- Ensure Openstack uses its own CinderManager [(#242)](https://github.com/ManageIQ/manageiq-providers-openstack/pull/242)

## Unreleased as of Sprint 82 ending 2018-03-26

### Fixed
- Improve provisioning failure error messages [(#254)](https://github.com/ManageIQ/manageiq-providers-openstack/pull/254)
- Correct network event target associations [(#250)](https://github.com/ManageIQ/manageiq-providers-openstack/pull/250)
- Dont return Storage Services if They arent present [(#240)](https://github.com/ManageIQ/manageiq-providers-openstack/pull/240)
- Filter openstack networks without subnets [(#238)](https://github.com/ManageIQ/manageiq-providers-openstack/pull/238)

## Unreleased as of Sprint 81 ending 2018-03-12

### Added
- Add delete_queue method for Template [(#236)](https://github.com/ManageIQ/manageiq-providers-openstack/pull/236)

## Gaprindashvili-2 released 2018-06-06

### Fixed
- Add back missing IP address range in Virtual Private Cloud name. [(#211)](https://github.com/ManageIQ/manageiq-providers-openstack/pull/211)
- Fix disable CloudTenant Vm targeted refresh [(#213)](https://github.com/ManageIQ/manageiq-providers-openstack/pull/213)
- Filter out duplicates during inventory collection [(#212)](https://github.com/ManageIQ/manageiq-providers-openstack/pull/212)
- Fix targeted refresh clearing vm cloud tenant for v2 [(#233)](https://github.com/ManageIQ/manageiq-providers-openstack/pull/233)

## Unreleased as of Sprint 80 ending 2018-02-26

### Fixed
- Improve network manager refresh speed [(#216)](https://github.com/ManageIQ/manageiq-providers-openstack/pull/216)

## Unreleased as of Sprint 79 ending 2018-02-12

### Added
- Add configurable vhost to AMQP monitor [(#221)](https://github.com/ManageIQ/manageiq-providers-openstack/pull/221)
- Store selected user sync roles as custom attributes. [(#210)](https://github.com/ManageIQ/manageiq-providers-openstack/pull/210)
- Infra discovery: Port scan needs trailing FF/LN [(#205)](https://github.com/ManageIQ/manageiq-providers-openstack/pull/205)

### Fixed
- Send tenant with identity service requests [(#225)](https://github.com/ManageIQ/manageiq-providers-openstack/pull/225)
- Repetitive storage volume deletion gives unexpected error [(#224)](https://github.com/ManageIQ/manageiq-providers-openstack/pull/224)
- Fix Service Provisioning cloud_tenant issue [(#223)](https://github.com/ManageIQ/manageiq-providers-openstack/pull/223)
- Add proper error message if network type not supported [(#222)](https://github.com/ManageIQ/manageiq-providers-openstack/pull/222)
- Don't require CinderManager in inventory classes [(#218)](https://github.com/ManageIQ/manageiq-providers-openstack/pull/218)
- Don't dependent => destroy cinder manager [(#214)](https://github.com/ManageIQ/manageiq-providers-openstack/pull/214)

## Gaprindashvili-1 - Released 2018-01-31

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
- Corrects handling of Notification params [(#171)](https://github.com/ManageIQ/manageiq-providers-openstack/pull/171)
- Skip disabled tenants when connecting to OpenStack [(#172)](https://github.com/ManageIQ/manageiq-providers-openstack/pull/172)
- If an image name is "", use the image's id instead [(#146)](https://github.com/ManageIQ/manageiq-providers-openstack/pull/146)
- Make sure volume template has name [(#148)](https://github.com/ManageIQ/manageiq-providers-openstack/pull/148)
- don't attempt cloning of OpenStack infra templates [(#153)](https://github.com/ManageIQ/manageiq-providers-openstack/pull/153)
- safe_call should catch Fog::Errors::NotFound [(#156)](https://github.com/ManageIQ/manageiq-providers-openstack/pull/156)
- Remove floating_ip_address from the create request if it is blank [(#145)](https://github.com/ManageIQ/manageiq-providers-openstack/pull/145)
- Fix missing quota calculations [(#158)](https://github.com/ManageIQ/manageiq-providers-openstack/pull/158)
- Restore missing quotas in new graph-based collector [(#159)](https://github.com/ManageIQ/manageiq-providers-openstack/pull/159)
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
- Fix Provisioning of disconnected VolumeTemplate [(#173)](https://github.com/ManageIQ/manageiq-providers-openstack/pull/173)
- Return empty AR relation instead of nil for ::InfraManager#cloud_tenants [(#184)](https://github.com/ManageIQ/manageiq-providers-openstack/pull/184)
- Fix refresh for private images [(#187)](https://github.com/ManageIQ/manageiq-providers-openstack/pull/187)
- Use only hypervisor hostname to match infra host with cloud vm [(#186)](https://github.com/ManageIQ/manageiq-providers-openstack/pull/186)
- If an image name is "" use the image's id instead [(#146)](https://github.com/ManageIQ/manageiq-providers-openstack/pull/146)
- manageiq-gems-pending is already from manageiq itself [(#141)](https://github.com/ManageIQ/manageiq-providers-openstack/pull/141)
- safe_call should catch Fog::Errors::NotFound [(#156)](https://github.com/ManageIQ/manageiq-providers-openstack/pull/156)
- Don't attempt cloning of OpenStack infra templates [(#153)](https://github.com/ManageIQ/manageiq-providers-openstack/pull/153)
- Remove floating_ip_address from the create request if it is blank [(#145)](https://github.com/ManageIQ/manageiq-providers-openstack/pull/145)
- Added supported_catalog_types [(#177)](https://github.com/ManageIQ/manageiq-providers-openstack/pull/177)
- Skip disabled tenants when connecting to OpenStack [(#172)](https://github.com/ManageIQ/manageiq-providers-openstack/pull/172)
- Corrects handling of Notification params [(#171)](https://github.com/ManageIQ/manageiq-providers-openstack/pull/171)
- Set VolumeTemplate name to ID if empty [(#169)](https://github.com/ManageIQ/manageiq-providers-openstack/pull/169)
- Include HelperMethods instead of extending [(#167)](https://github.com/ManageIQ/manageiq-providers-openstack/pull/167)
- Don't pass nil ssl_options to try_connection [(#166)](https://github.com/ManageIQ/manageiq-providers-openstack/pull/166)
- Add missing 'return' statement to 'network_manager.find_device_object' [(#188)](https://github.com/ManageIQ/manageiq-providers-openstack/pull/188)
- Fix refresh for private images [(#187)](https://github.com/ManageIQ/manageiq-providers-openstack/pull/187)
- Use only hypervisor hostname to match infra host with cloud vm [(#186)](https://github.com/ManageIQ/manageiq-providers-openstack/pull/186)
- Return empty AR relation instead of nil for ::InfraManager#cloud_tenants [(#184)](https://github.com/ManageIQ/manageiq-providers-openstack/pull/184)
- Improve Targeted Refresh for Cloud and Network managers [(#175)](https://github.com/ManageIQ/manageiq-providers-openstack/pull/175)
- Bypass the superclass orchestrated destroy for this Provider. [(#209)](https://github.com/ManageIQ/manageiq-providers-openstack/pull/209)
- Don't dependent => destroy child_managers [(#208)](https://github.com/ManageIQ/manageiq-providers-openstack/pull/208)
- Override az_zone_to_cloud_network in openstack prov [(#202)](https://github.com/ManageIQ/manageiq-providers-openstack/pull/202)
- Correct the paths that event target IDs are parsed from [(#195)](https://github.com/ManageIQ/manageiq-providers-openstack/pull/195)
- Ensure that subnets are dissociated from routers in the ManageIQ inventory when their interfaces are removed on the OSP side [(#182)](https://github.com/ManageIQ/manageiq-providers-openstack/pull/182)

### Removed
- Remove old refresh settings [(#135)](https://github.com/ManageIQ/manageiq-providers-openstack/pull/135)

## Unreleased as of Sprint 78 ending 2018-01-29

### Added
- Added keystone_v3_domain_id to api_allowed_attributes method [(#196)](https://github.com/ManageIQ/manageiq-providers-openstack/pull/196)

### Fixed
- Provider base class handles the managers' destroy now [(#198)](https://github.com/ManageIQ/manageiq-providers-openstack/pull/198)
- Extend allowed_cloud_network for providers that don't support allowed_ci [(#197)](https://github.com/ManageIQ/manageiq-providers-openstack/pull/197)
- Implement graph refresh for the Cinder manager [(#194)](https://github.com/ManageIQ/manageiq-providers-openstack/pull/194)
- Track guest OS for openstack images and VMs [(#193)](https://github.com/ManageIQ/manageiq-providers-openstack/pull/193)

## Unreleased as of Sprint 75 ending 2017-12-11

### Fixed
- Handle attempts to delete volumes that have already been deleted [(#147)](https://github.com/ManageIQ/manageiq-providers-openstack/pull/147)
- Replace conditions with scope [(#144)](https://github.com/ManageIQ/manageiq-providers-openstack/pull/144)

## Unreleased as of Sprint 74 ending 2017-11-27

### Fixed
- Add error message if FIP assigned to router [(#161)](https://github.com/ManageIQ/manageiq-providers-openstack/pull/161)

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

## Initial changelog added
