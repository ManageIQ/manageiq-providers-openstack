# manageiq-providers-openstack

[![Gem Version](https://badge.fury.io/rb/manageiq-providers-openstack.svg)](http://badge.fury.io/rb/manageiq-providers-openstack)
[![Build Status](https://travis-ci.org/ManageIQ/manageiq-providers-openstack.svg)](https://travis-ci.org/ManageIQ/manageiq-providers-openstack)
[![Code Climate](https://codeclimate.com/github/ManageIQ/manageiq-providers-openstack.svg)](https://codeclimate.com/github/ManageIQ/manageiq-providers-openstack)
[![Test Coverage](https://codeclimate.com/github/ManageIQ/manageiq-providers-openstack/badges/coverage.svg)](https://codeclimate.com/github/ManageIQ/manageiq-providers-openstack/coverage)
[![Dependency Status](https://gemnasium.com/ManageIQ/manageiq-providers-openstack.svg)](https://gemnasium.com/ManageIQ/manageiq-providers-openstack)
[![Security](https://hakiri.io/github/ManageIQ/manageiq-providers-openstack/master.svg)](https://hakiri.io/github/ManageIQ/manageiq-providers-openstack/master)

[![Chat](https://badges.gitter.im/Join%20Chat.svg)](https://gitter.im/ManageIQ/manageiq-providers-openstack?utm_source=badge&utm_medium=badge&utm_campaign=pr-badge&utm_content=badge)
[![Translate](https://img.shields.io/badge/translate-zanata-blue.svg)](https://translate.zanata.org/zanata/project/view/manageiq-providers-openstack)

ManageIQ plugin for the Openstack provider.

## Development
Test CI
See the section on pluggable providers in the [ManageIQ Developer Setup](http://manageiq.org/docs/guides/developer_setup)

For quick local setup run `bin/setup`, which will clone the core ManageIQ repository under the *spec* directory and setup necessary config files. If you have already cloned it, you can run `bin/update` to bring the core ManageIQ code up to date.

### VCR cassettes re-recording

You will need testing OpenStack environment(s) and `openstack_environments.yml` file with credentials in format like:
```yml
---
- test_env_1:
    ip: 11.22.33.44
    password: long_password_1
    user: admin_1
- test_env_2:
    ip: 11.22.33.55
    password: long_password_2
    user: admin_2
```

Then you can run `bundle exec rake vcr:rerecord` and following will happen:
* Current VCR cassettes files will be deleted
* Credentials from `openstack_environments.yml` file will be injected into spec files
* Specs needed for re-recording of VCR cassettes will be run. During this step manageiq will call OpenStack APIs at specified endpoints
* Credentials present in spec files and VCR cassettes will be changed to dummy data so tests can run from VCR cassettes

## License

The gem is available as open source under the terms of the [Apache License 2.0](http://www.apache.org/licenses/LICENSE-2.0).

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
