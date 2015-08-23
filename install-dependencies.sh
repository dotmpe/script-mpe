#!/usr/bin/env bash

# dev deps only atm

test -n "$SRC_PREFIX" || SRC_PREFIX=$HOME

# Check for BATS shell test runner or install
test -x "$(which bats)" && {
  bats --version
} || {
  echo "Installing bats"
  pushd $SRC_PREFIX
  git clone https://github.com/sstephenson/bats.git
  cd bats
  sudo ./install.sh /usr/local
  popd
  bats --version
}

# Id: git-versioning/0.0.27-test install-dependencies.sh
