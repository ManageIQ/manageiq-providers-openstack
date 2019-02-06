# Change Log

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](http://keepachangelog.com/en/1.0.0/)


## Unreleased as of Sprint 104 ending 2019-02-04

### Fixed
- Warn but still allow infra without ironic [(#436)](https://github.com/ManageIQ/manageiq-providers-openstack/pull/436)

## Unreleased as of Sprint 103 ending 2019-01-21

### Added
- Improve handling of missing services [(#411)](https://github.com/ManageIQ/manageiq-providers-openstack/pull/411)

### Changed
- Improve handling of missing services [(#411)](https://github.com/ManageIQ/manageiq-providers-openstack/pull/411)

### Fixed
- Read back to catch events that may have reached Panko out of order [(#433)](https://github.com/ManageIQ/manageiq-providers-openstack/pull/433)
- Get tenant for stack from parameters [(#417)](https://github.com/ManageIQ/manageiq-providers-openstack/pull/417)

## Unreleased as of Sprint 102 ending 2019-01-07

### Fixed
- Targeted refresh: Collect tenant ems references last [(#422)](https://github.com/ManageIQ/manageiq-providers-openstack/pull/422)
- Remove legacy network collection from CloudManager graph refresh [(#421)](https://github.com/ManageIQ/manageiq-providers-openstack/pull/421)

## Hammer-1

### Added
- Pass openstack_admin? flag to volume snapshot template collection [(#359)](https://github.com/ManageIQ/manageiq-providers-openstack/pull/359)
- Support the :cinder_volume_types feature in the CinderManager [(#358)](https://github.com/ManageIQ/manageiq-providers-openstack/pull/358)
- Make `default_security_group` visible in the API [(#355)](https://github.com/ManageIQ/manageiq-providers-openstack/pull/355)
- Use UUID if volume name is missing [(#351)](https://github.com/ManageIQ/manageiq-providers-openstack/pull/351)
- Moving Inventory Builder functionality to Inventory [(#343)](https://github.com/ManageIQ/manageiq-providers-openstack/pull/343)
- Infra Discovery: support for SSL [(#326)](https://github.com/ManageIQ/manageiq-providers-openstack/pull/326)
- Collect Cinder Volume Types during Inventory Refresh [(#305)](https://github.com/ManageIQ/manageiq-providers-openstack/pull/305)
- Instances workflow: Allow flavors with disk size of 0 [(#314)](https://github.com/ManageIQ/manageiq-providers-openstack/pull/314)
- Persister: optimized InventoryCollection definitions [(#307)](https://github.com/ManageIQ/manageiq-providers-openstack/pull/307)
- Add display name for flavor [(#302)](https://github.com/ManageIQ/manageiq-providers-openstack/pull/302)
- Add Openstack CinderManager EventCatcher [(#281)](https://github.com/ManageIQ/manageiq-providers-openstack/pull/281)
- Update VCRs and remove obsolete VCRs for very old versions of Openstack [(#266)](https://github.com/ManageIQ/manageiq-providers-openstack/pull/266)
- Add delete_queue method for Template [(#236)](https://github.com/ManageIQ/manageiq-providers-openstack/pull/236)
- Store selected user sync roles as custom attributes. [(#210)](https://github.com/ManageIQ/manageiq-providers-openstack/pull/210)
- Added keystone_v3_domain_id to api_allowed_attributes method [(#196)](https://github.com/ManageIQ/manageiq-providers-openstack/pull/196)
- Adds vm_snapshot_success Notification creation [(#128)](https://github.com/ManageIQ/manageiq-providers-openstack/pull/128)
- Trim Volume error messages out of Fog responses [(#123)](https://github.com/ManageIQ/manageiq-providers-openstack/pull/123)
- Enable provisioning from Volumes and Volume Snapshots via a proxy type [(#104)](https://github.com/ManageIQ/manageiq-providers-openstack/pull/104)
- Orchestration Stack and Cloud Tenant targeted refresh [(#86)](https://github.com/ManageIQ/manageiq-providers-openstack/pull/86)
- Add notifications for VM destroy Cloud Volume and Cloud Volume Snapshot actions [(#85)](https://github.com/ManageIQ/manageiq-providers-openstack/pull/85)
- Trim error messages from fog responses for remaining models [(#130)](https://github.com/ManageIQ/manageiq-providers-openstack/pull/130)
- Update i18n catalog for hammer [(#368)](https://github.com/ManageIQ/manageiq-providers-openstack/pull/368)

### Fixed
- Add StorageManager modules to fix CinderManager import paths [(#352)](https://github.com/ManageIQ/manageiq-providers-openstack/pull/352)
- Use empty name for volume if only size provided [(#344)](https://github.com/ManageIQ/manageiq-providers-openstack/pull/344)
- Add cores per socket to OpenStack cloud inventory parser [(#341)](https://github.com/ManageIQ/manageiq-providers-openstack/pull/341)
- Flavors: always include private flavors [(#329)](https://github.com/ManageIQ/manageiq-providers-openstack/pull/329)
- Require hostname if provider is enabled [(#322)](https://github.com/ManageIQ/manageiq-providers-openstack/pull/322)
- Add template decorator [(#309)](https://github.com/ManageIQ/manageiq-providers-openstack/pull/309)
- Default volume size value in provisioning [(#289)](https://github.com/ManageIQ/manageiq-providers-openstack/pull/289)
- per_volume_gigabytes_used definition is missing [(#276)](https://github.com/ManageIQ/manageiq-providers-openstack/pull/276)
- Use the correct id when collecting quotas from Neutron [(#272)](https://github.com/ManageIQ/manageiq-providers-openstack/pull/272)
- translate_exceptions: Parse errors out of fog responses [(#271)](https://github.com/ManageIQ/manageiq-providers-openstack/pull/271)
- Don't lose VM volume attachments when refreshing the cloud inventory [(#243)](https://github.com/ManageIQ/manageiq-providers-openstack/pull/243)
- Avoid tenant discovery recursion [(#265)](https://github.com/ManageIQ/manageiq-providers-openstack/pull/265)
- Parse volume attachment/detachment messages from fog responses [(#253)](https://github.com/ManageIQ/manageiq-providers-openstack/pull/253)
- Ensure Openstack uses its own CinderManager [(#242)](https://github.com/ManageIQ/manageiq-providers-openstack/pull/242)
- Repetitive storage volume deletion gives unexpected error [(#224)](https://github.com/ManageIQ/manageiq-providers-openstack/pull/224)
- Fix Service Provisioning cloud_tenant issue [(#223)](https://github.com/ManageIQ/manageiq-providers-openstack/pull/223)
- Add proper error message if network type not supported [(#222)](https://github.com/ManageIQ/manageiq-providers-openstack/pull/222)
- Don't require CinderManager in inventory classes [(#218)](https://github.com/ManageIQ/manageiq-providers-openstack/pull/218)
- Don't dependent => destroy cinder manager [(#214)](https://github.com/ManageIQ/manageiq-providers-openstack/pull/214)
- Provider base class handles the managers' destroy now [(#198)](https://github.com/ManageIQ/manageiq-providers-openstack/pull/198)
- Extend allowed_cloud_network for providers that don't support allowed_ci [(#197)](https://github.com/ManageIQ/manageiq-providers-openstack/pull/197)
- Implement graph refresh for the Cinder manager [(#194)](https://github.com/ManageIQ/manageiq-providers-openstack/pull/194)
- Handle attempts to delete volumes that have already been deleted [(#147)](https://github.com/ManageIQ/manageiq-providers-openstack/pull/147)
- Replace conditions with scope [(#144)](https://github.com/ManageIQ/manageiq-providers-openstack/pull/144)
- Add error message if FIP assigned to router [(#161)](https://github.com/ManageIQ/manageiq-providers-openstack/pull/161)
- Translate exceptions from raw_connect [(#132)](https://github.com/ManageIQ/manageiq-providers-openstack/pull/132)
- Fix for amqp events [(#131)](https://github.com/ManageIQ/manageiq-providers-openstack/pull/131)
- Update event parser code to deal with amqp messages [(#127)](https://github.com/ManageIQ/manageiq-providers-openstack/pull/127)
- Trim key pair errors out of api responses [(#120)](https://github.com/ManageIQ/manageiq-providers-openstack/pull/120)
- Only update tenant mapping for the network manager if it's present [(#119)](https://github.com/ManageIQ/manageiq-providers-openstack/pull/119)
- Update raw connect method to accomodate OpenStack complexity [(#118)](https://github.com/ManageIQ/manageiq-providers-openstack/pull/118)
- Trim neutron error messages out of fog responses [(#110)](https://github.com/ManageIQ/manageiq-providers-openstack/pull/110) 
- Direct attribute access for `cloud_volume_types` via cloud_tenants API [(#366)](https://github.com/ManageIQ/manageiq-providers-openstack/pull/366)
- Get images with pagination loop [(#363)](https://github.com/ManageIQ/manageiq-providers-openstack/pull/363)
- Don't use string interpolations inside gettext strings [(#369)](https://github.com/ManageIQ/manageiq-providers-openstack/pull/369)
- New Cloud provider: Fix event creds validation for AMQP [(#399)](https://github.com/ManageIQ/manageiq-providers-openstack/pull/399)
- Better neutron exception handling condition [(#371)](https://github.com/ManageIQ/manageiq-providers-openstack/pull/371)
- Service dialog for orchestration template needs tenant selection [(#397)](https://github.com/ManageIQ/manageiq-providers-openstack/pull/397)
- Check if host create event exists and assign host to it [(#380)](https://github.com/ManageIQ/manageiq-providers-openstack/pull/380)
- Add explicit runtime dependency on the "parallel" gem [(#403)](https://github.com/ManageIQ/manageiq-providers-openstack/pull/403)
- Require 'parallel' in the OpenstackHandle [(#404)](https://github.com/ManageIQ/manageiq-providers-openstack/pull/404)
- Avoid uniqueness constraint violations in sync_users [(#373)](https://github.com/ManageIQ/manageiq-providers-openstack/pull/373)
- For OpenStack infra validation, validate presence of Ironic [(#379)](https://github.com/ManageIQ/manageiq-providers-openstack/pull/379)
- New Cloud provider: Fix event creds validation for AMQP [(#324)](https://github.com/ManageIQ/manageiq-providers-openstack/pull/324)
- Format error when physical network is in use [(#370)](https://github.com/ManageIQ/manageiq-providers-openstack/pull/370)
- Collect Panko events for all tenants. [(#402)](https://github.com/ManageIQ/manageiq-providers-openstack/pull/402)

### Removed
- Remove useless EmsRefresherMixin [(#304)](https://github.com/ManageIQ/manageiq-providers-openstack/pull/304)

## Unreleased as of Sprint 101 ending 2018-12-17

### Fixed
- Exclude already attached VMs from the volume attachment form [(#409)](https://github.com/ManageIQ/manageiq-providers-openstack/pull/409)

## Unreleased as of Sprint 100 ending 2018-12-03

### Added
- Add supports_conversion_host to Vm [(#407)](https://github.com/ManageIQ/manageiq-providers-openstack/pull/407)
- Add a default parallel thread limit to the settings yaml [(#405)](https://github.com/ManageIQ/manageiq-providers-openstack/pull/405)

### Fixed
- Fix autocomplete error in targeted Cloud Volume collection [(#400)](https://github.com/ManageIQ/manageiq-providers-openstack/pull/400)

## Unreleased as of Sprint 99 ending 2018-11-19

### Added
- Add support for multiple amqp endpoints [(#394)](https://github.com/ManageIQ/manageiq-providers-openstack/pull/394)
- Refresh an attached undercloud when saving changes to an overcloud [(#393)](https://github.com/ManageIQ/manageiq-providers-openstack/pull/393)
- Parallelize OpenstackHandle [(#374)](https://github.com/ManageIQ/manageiq-providers-openstack/pull/374)

## Unreleased as of Sprint 98 ending 2018-11-05

### Added
- When doing targeted refresh of a volume refresh any attached VMs [(#386)](https://github.com/ManageIQ/manageiq-providers-openstack/pull/386)

## Gaprindashvili-6 - Released 2018-11-02

### Fixed
- Require hostname if provider is enabled [(#322)](https://github.com/ManageIQ/manageiq-providers-openstack/pull/322)
- Filter Keystone Projects by domain_id [(#342)](https://github.com/ManageIQ/manageiq-providers-openstack/pull/342)
- Use empty name for volume if only size provided [(#344)](https://github.com/ManageIQ/manageiq-providers-openstack/pull/344)

## Gaprindashvili-5 - Released 2018-09-07

### Added
- Add configurable vhost to AMQP monitor [(#221)](https://github.com/ManageIQ/manageiq-providers-openstack/pull/221)

### Fixed
- Catch Bad Request responses in safe_call [(#330)](https://github.com/ManageIQ/manageiq-providers-openstack/pull/330)

## Gaprindashvili-4

### Fixed
- Catch error when volume creation fails [(#269)](https://github.com/ManageIQ/manageiq-providers-openstack/pull/269)
- Make Gnocchi default granularity configurable in Settings [(#267)](https://github.com/ManageIQ/manageiq-providers-openstack/pull/267)
- duplicate opts hash before modifying in raw_connect_try_ssl [(#284)](https://github.com/ManageIQ/manageiq-providers-openstack/pull/284)
- Combine InfraManager and child manager refresh queues [(#286)](https://github.com/ManageIQ/manageiq-providers-openstack/pull/286)
- Fix targeted refresh builder params for network objects [(#290)](https://github.com/ManageIQ/manageiq-providers-openstack/pull/290)
- Friendly error message for HTTP 503 [(#293)](https://github.com/ManageIQ/manageiq-providers-openstack/pull/293)
- Fix tenant associations on VolumeSnapshotTemplates [(#310)](https://github.com/ManageIQ/manageiq-providers-openstack/pull/310)

## Gaprindashvili-3 - Released 2018-05-15

### Added
- Infra discovery: Port scan needs trailing FF/LN [(#205)](https://github.com/ManageIQ/manageiq-providers-openstack/pull/205)
- For archived nodes, just delete AR object on remove [(#165)](https://github.com/ManageIQ/manageiq-providers-openstack/pull/165)
- Move CinderManager inventory classes [(#282)](https://github.com/ManageIQ/manageiq-providers-openstack/pull/282)

### Fixed
- Send tenant with identity service requests [(#225)](https://github.com/ManageIQ/manageiq-providers-openstack/pull/225)
- Track guest OS for openstack images and VMs [(#193)](https://github.com/ManageIQ/manageiq-providers-openstack/pull/193)
- Improve network manager refresh speed [(#216)](https://github.com/ManageIQ/manageiq-providers-openstack/pull/216)
- Correct network event target associations [(#250)](https://github.com/ManageIQ/manageiq-providers-openstack/pull/250)
- Improve provisioning failure error messages [(#254)](https://github.com/ManageIQ/manageiq-providers-openstack/pull/254)
- Filter openstack networks without subnets [(#238)](https://github.com/ManageIQ/manageiq-providers-openstack/pull/238)
- Dont return Storage Services if They arent present [(#240)](https://github.com/ManageIQ/manageiq-providers-openstack/pull/240)
- Fix parent subnet relationship [(#260)](https://github.com/ManageIQ/manageiq-providers-openstack/pull/260)
- Fallback to generic error parsing if neutron-specific parsing fails [(#263)](https://github.com/ManageIQ/manageiq-providers-openstack/pull/263)
- Default Event payload to empty Hash [(#262)](https://github.com/ManageIQ/manageiq-providers-openstack/pull/262)
- Fixes unfriendly message when adding network for unavailable provider [(#264)](https://github.com/ManageIQ/manageiq-providers-openstack/pull/264)
- Catch Fog::Errors::NotFound in OpenstackHandle.handled_list [(#280)](https://github.com/ManageIQ/manageiq-providers-openstack/pull/280)

## Gaprindashvili-2 released 2018-06-06

### Fixed
- Add back missing IP address range in Virtual Private Cloud name. [(#211)](https://github.com/ManageIQ/manageiq-providers-openstack/pull/211)
- Fix disable CloudTenant Vm targeted refresh [(#213)](https://github.com/ManageIQ/manageiq-providers-openstack/pull/213)
- Filter out duplicates during inventory collection [(#212)](https://github.com/ManageIQ/manageiq-providers-openstack/pull/212)
- Fix targeted refresh clearing vm cloud tenant for v2 [(#233)](https://github.com/ManageIQ/manageiq-providers-openstack/pull/233)

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

## Initial changelog added
