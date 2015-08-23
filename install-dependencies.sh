#!/usr/bin/env bash


test -n "$SRC_PREFIX" || SRC_PREFIX=$HOME

test -d ~/bin || mkdir ~/bin

install_bats()
{
  echo "Installing bats"
  pushd $SRC_PREFIX
  git clone https://github.com/sstephenson/bats.git
  cd bats
  ./install.sh ~/bin/
  popd
}

install_mkdoc()
{
  echo "Installing mkdoc"
  pushd $SRC_PREFIX
  git clone https://github.com/dotmpe/mkdoc.git
  cd mkdoc
  git co devel
  PREFIX=~/usr/ ./configure && ./install.sh
  popd
  rm Makefile
  ln -s ~/usr/share/mkdoc/Mkdoc-full.mk Makefile
  make
}

# Check for BATS shell test runner or install
test -x "$(which bats)" && {
  bats --version
} || {
  install_bats
  bats --version
}

install_mkdoc

