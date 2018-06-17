#!/bin/sh

set -e

# Something to manage messages
test -n "$LOG" -a -x "$LOG" || exit 170

# Place to store Box files
test -n "$BOX_DIR" || export BOX_DIR=$HOME/.box

# Place for all Box frontends
test -n "$BOX_BIN_DIR" || export BOX_BIN_DIR=$BOX_DIR/frontend

# Mark env or fail on reload
test -z "$BOX_INIT" && BOX_INIT=1 || {
    $LOG "box.env" error "unexpected re-init" 1
    #echo "box.env" error "unexpected re-init" 1>&2 ; return 1
}

# run-time test since box relies on local vars and Bash seems to mess up
box_run_sh_test()
{
  set | grep '^main.*()\s*$' >/dev/null && {
    error "please use sh, or bash -o 'posix'" 5
  } || {
    return 0
  }
}
