#!/usr/bin/env bash

PREFIX=~/usr

test -n "$SRC_PREFIX" || SRC_PREFIX=$HOME

test -n "$PREFIX" || {
  echo "Not sure where to install"
  exit 1
}

test -d $SRC_PREFIX || mkdir -vp $SRC_PREFIX
test -d $PREFIX || mkdir -vp $PREFIX


install_bats()
{
  echo "Installing bats"
  pushd $SRC_PREFIX
  git clone https://github.com/sstephenson/bats.git
  cd bats
  ./install.sh $PREFIX
  popd
}

install_mkdoc()
{
  echo "Installing mkdoc"
  pushd $SRC_PREFIX
  git clone https://github.com/dotmpe/mkdoc.git
  cd mkdoc
  git checkout devel
  PREFIX=~/usr/ ./configure && ./install.sh
  popd
  rm Makefile
  ln -s ~/usr/share/mkdoc/Mkdoc-full.mk Makefile
  make
}

# Check for BATS shell test runner or install
test -x "$(which bats)" || {
  install_bats
  export PATH=$PATH:$PREFIX/bin
}

bats --version

install_mkdoc

sudo pip install jsonschema

# Id: script-mpe/0 install-dependencies.sh

