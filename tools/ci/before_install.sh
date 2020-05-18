#!/bin/bash
set -v
pushd $PWD

# Install the dev dependencies for building Qpid proton system library.
sudo apt-get install -y gcc cmake cmake-curses-gui uuid-dev
sudo apt-get install -y libssl-dev
sudo apt-get install -y libsasl2-2 libsasl2-dev

# Get the latest Qpid Proton source
cd $HOME/build
git clone --branch 0.30.0 https://github.com/apache/qpid-proton.git
cd qpid-proton

# Configure the source of Qpid Proton.
mkdir build
cd build
cmake .. -DCMAKE_INSTALL_PREFIX=/usr -DBUILD_BINDINGS=

# Compile system libraries.
make all

# Install system libraries
sudo make install

# Enable the qpid_proton bundler group
[ -z "$BUNDLE_WITH" ] && bundle config with qpid_proton

popd
set +v
