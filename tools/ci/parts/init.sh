#!/bin/dash

# Using dash to allow brace-expansion, just in the init script

note "Entry for CI pre-install / init phase"


# Basicly if these don't run dont bother with anything,
# But cannot abort/skip a Travis build without failure, can they?

# This is also like the classic software ./configure.sh stage.


pwd && pwd -P
whoami
( env | grep -i 'shippable\|travis\|ci' ) || noop


mkdir -vp ~/.local/{bin,lib,share}

falseish "$SHIPPABLE" || {
  mkdir -vp shippable/{testresults,codecoverage}
  test -d shippable/codecoverage
}

fnmatch "* basename-reg *" "$TEST_FEATURES" && {
  test -e $HOME/.basename-reg.yaml ||
    touch $HOME/.basename-reg.yaml
}


note "Done"

