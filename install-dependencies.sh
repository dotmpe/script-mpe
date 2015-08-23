#!/usr/bin/env bash


test -n "$SRC_PREFIX" || SRC_PREFIX=$HOME


install_bats()
{
  echo "Installing bats"
  pushd $SRC_PREFIX
  git clone https://github.com/sstephenson/bats.git
  cd bats
  sudo ./install.sh /usr/local
  popd
}

install_mkdoc()
{
  echo "Installing mkdoc"
  pushd $SRC_PREFIX
  git clone https://github.com/dotmpe/mkdoc.git
  cd mkdoc
  ./configure && sudo ./install.sh
  popd
}

# Check for BATS shell test runner or install
test -x "$(which bats)" && {
  bats --version
} || {
  install_bats
  bats --version
}

install_mkdoc

