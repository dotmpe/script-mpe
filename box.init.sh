#!/bin/sh

set -e

test -n "$UCONFDIR" || UCONFDIR=$HOME/.conf
test -n "$BOX_DIR" || {
  BOX_DIR=$UCONFDIR/box
}
test -n "$BOX_BIN_DIR" || {
  test -n "$uname" || uname=$(uname -s)
  BOX_BIN_DIR=$UCONFDIR/script/$uname
  test -d $BOX_BIN_DIR || mkdir -vp $BOX_BIN_DIR
}

test -n "$scriptpath" || error "box.init: scriptpath missing" 1

test -z "$BOX_INIT" && BOX_INIT=1 || error "unexpected re-init" 1

# run-time test since box relies on local vars and bash seems to mess up
box_run_sh_test()
{
  set | grep '^main.*()\s*$' >/dev/null && {
    error "please use sh, or bash -o 'posix'" 5
  } || {
    return 0
  }
}

