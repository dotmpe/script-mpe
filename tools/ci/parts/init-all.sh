#!/usr/bin/env bash

# XXX: $script_util/parts/init.sh all

sh_include init

init-all()
{
  init-basher || return
  check-bats
}


# Basicly if these don't run dont bother with anything,
# But cannot abort/skip a Travis build without failure, can they?

# This is also like the classic software ./configure.sh stage.

test -z "${BUILD_ID:-}" || {
  test ! -d build || {
    rm -rf build
    $LOG note "" "Cleaned build/"
  }
  mkdir -vp build
}

( mkdir -vp ~/.local && cd ~/.local/ && mkdir -vp  bin lib share )
mkdir ~/build/local

not_trueish "$SHIPPABLE" || {
  mkdir -vp shippable/{testresults,codecoverage}
  test -d shippable/codecoverage
}

fnmatch "* basename-reg *" " $TEST_SPECS " && {
  test -e ~/.basename-reg.yaml ||
    cp basename-reg.yaml ~/.basename-reg.yaml
}

# Sync: U-S:
