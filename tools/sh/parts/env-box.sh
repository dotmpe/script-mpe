#!/usr/bin/env bash

set -e -o nounset -o pipefail

# Something to manage messages
test -n "${INIT_LOG:-}" -a -x "${INIT_LOG:-}" || exit 102 # NOTE: sanity

# Place to store Box files
test -n "${BOX_DIR:-}" || {
    true "${UCONF:="$HOME/.conf"}"
    test -d "$UCONF/script/box" &&
        export BOX_DIR=$UCONF/script/box ||
        export BOX_DIR=$HOME/.local/box
}

# Place for all Box frontends
test -n "${BOX_BIN_DIR:-}" || export BOX_BIN_DIR=$BOX_DIR/bin

# Mark env or fail on reload
test -z "${BOX_INIT:-}" && BOX_INIT=1 || {
  $INIT_LOG error "box.env" "unexpected re-init" "" 1
}

# run-time test since box relies on local vars and Bash seems to mess up
box_run_sh_test()
{
  set | grep '^main.*()\s*$' >/dev/null && {
    $INIT_LOG error "box.env" "please use sh, or bash -o 'posix'" "$0" 5
  } || {
    $INIT_LOG info "box.env" "Test ok" "$0"
    return 0
  }
}

$INIT_LOG info "box.env" "Loaded" "$0"

# Sync: U-S:
