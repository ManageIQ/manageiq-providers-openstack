# ManageIQ::Providers::Openstack

[![Build Status](https://travis-ci.com/ManageIQ/manageiq-providers-openstack.svg?branch=kasparov)](https://travis-ci.com/ManageIQ/manageiq-providers-openstack)
[![Maintainability](https://api.codeclimate.com/v1/badges/d4ac5021ef2927f3b3a7/maintainability)](https://codeclimate.com/github/ManageIQ/manageiq-providers-openstack/maintainability)
[![Test Coverage](https://api.codeclimate.com/v1/badges/d4ac5021ef2927f3b3a7/test_coverage)](https://codeclimate.com/github/ManageIQ/manageiq-providers-openstack/test_coverage)
[![Security](https://hakiri.io/github/ManageIQ/manageiq-providers-openstack/kasparov.svg)](https://hakiri.io/github/ManageIQ/manageiq-providers-openstack/kasparov)

[![Chat](https://badges.gitter.im/Join%20Chat.svg)](https://gitter.im/ManageIQ/manageiq-providers-openstack?utm_source=badge&utm_medium=badge&utm_campaign=pr-badge&utm_content=badge)

ManageIQ plugin for the OpenStack provider.

## Development

See the section on plugins in the [ManageIQ Developer Setup](http://manageiq.org/docs/guides/developer_setup/plugins)

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
