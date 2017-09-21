# Change Log

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](http://keepachangelog.com/en/1.0.0/)


## Unreleased as of Sprint 69 ending 2017-09-18

### Added
- Fix collector caching and improve collection of network relations for targeted refresh [(#82)](https://github.com/ManageIQ/manageiq-providers-openstack/pull/82)
- Add class for parsing refresh targets from EmsEvents [(#81)](https://github.com/ManageIQ/manageiq-providers-openstack/pull/81)

### Fixed
- Add flavors info in instance provisioning [(#91)](https://github.com/ManageIQ/manageiq-providers-openstack/pull/91)
- Old Refresh: Don't error out if a port refers to an unknown subnet. [(#90)](https://github.com/ManageIQ/manageiq-providers-openstack/pull/90)
- Reading mac from the reported port correctly [(#87)](https://github.com/ManageIQ/manageiq-providers-openstack/pull/87)

## Unreleased as of Sprint 68 ending 2017-09-04

### Added
- Add cloud volume restore and delete raw actions. Cloud volume backup [(#83)](https://github.com/ManageIQ/manageiq-providers-openstack/pull/83)
- Add vm security group operations [(#79)](https://github.com/ManageIQ/manageiq-providers-openstack/pull/79)
- Add scale_down and scale_up tasks to OrchestrationStack [(#55)](https://github.com/ManageIQ/manageiq-providers-openstack/pull/55)

## Unreleased as of Sprint 67 ending 2017-08-21

### Fixed
- Update miq-module dependency to more_core_extensions [(#77)](https://github.com/ManageIQ/manageiq-providers-openstack/pull/77)
- Update provision requirements check to allow exact matches [(#72)](https://github.com/ManageIQ/manageiq-providers-openstack/pull/72)

### Added
- Targeted Refresh for Cloud VMs [(#74)](https://github.com/ManageIQ/manageiq-providers-openstack/pull/74)

## Unreleased as of Sprint 66 ending 2017-08-07

### Fixed
- Handle case where do_volume_creation_check gets a nil from Fog [(#73)](https://github.com/ManageIQ/manageiq-providers-openstack/pull/73)
- Assign only compact and unique list of hosts [(#71)](https://github.com/ManageIQ/manageiq-providers-openstack/pull/71)

### Added
- Adds specific methods for creating, deleting flavors. [(#65)](https://github.com/ManageIQ/manageiq-providers-openstack/pull/65)
