# Change Log

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](http://keepachangelog.com/en/1.0.0/)


## Gaprindashvili-2

### Fixed
- Add back missing IP address range in Virtual Private Cloud name. [(#211)](https://github.com/ManageIQ/manageiq-providers-openstack/pull/211)
- Fix disable CloudTenant Vm targeted refresh [(#213)](https://github.com/ManageIQ/manageiq-providers-openstack/pull/213)
- Filter out duplicates during inventory collection [(#212)](https://github.com/ManageIQ/manageiq-providers-openstack/pull/212)
- Fix targeted refresh clearing vm cloud tenant for v2 [(#233)](https://github.com/ManageIQ/manageiq-providers-openstack/pull/233)

## Gaprindashvili-1 - Released 2018-02-01

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

### Removed
- Remove old refresh settings [(#135)](https://github.com/ManageIQ/manageiq-providers-openstack/pull/135)
