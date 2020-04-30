#!/usr/bin/env bash
test -z "${sh_util_:-}" && sh_util_=1 || return 198 # Recursion

# XXX: enable for CI? info() { exit 123; }

# TODO: move some of below to CI util.sh

git_version()
{
  test $# -eq 1 -a -d "$1" || return
  ( test "$PWD" = "$1" || cd "$1"
    git describe --always )
}

test -n "${U_S-}" ||
  $LOG "error" "" "Expected U-S env" "" 1

test -d $U_S/.git || {
  test "${ENV_DEV-}" = "1" && {
    {
      test ! -d "$U_S" || rm -rf "$U_S"
      git clone https://github.com/dotmpe/user-scripts.git $U_S
    }
    ( cd $U_S/ && git fetch --all &&
        git checkout feature/docker-ci &&
        git pull origin feature/docker-ci )
  } ||
      $LOG "error" "" "Expected U-S checkout" "" 1
}

. $PWD/tools/sh/init-include.sh # Initialize sh_include

sh_include \
    str-bool str-id read exec hd-offsets suite-from-table suite-source suite-run
# XXX: sh_include offsets


# Sync: X-CI-0.1:
# Sync: U-S:
