# Declare your gem's dependencies in manageiq-providers-openstack.gemspec.
# Bundler will treat runtime dependencies like base dependencies, and
# development dependencies will be added by default to the :development group.
gemspec

# Declare any dependencies that are still in development here instead of in
# your gemspec. These might include edge Rails or gems from your path or
# Git. Remember to move these dependencies to your gemspec before releasing
# your gem to rubygems.org.

# We are using 'miq-module' from gems-pending
gem "manageiq-gems-pending", ">0", :require => 'manageiq-gems-pending', :git => "https://github.com/ManageIQ/manageiq-gems-pending.git", :branch => "master"

# Load Gemfile with dependencies from manageiq
eval_gemfile(File.expand_path("spec/manageiq/Gemfile", __dir__))
