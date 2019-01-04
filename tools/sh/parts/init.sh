#!/usr/bin/env bash
#
# Provisioning and project init helpers

usage()
{
  echo 'Usage:'
  echo '  ./tools/sh/parts/init.sh <function name>'
}
usage-fail() { usage && exit 2; }



# Groups

default()
{
  # TODO: see +U_s
  true
}

# Main

type req_subcmd >/dev/null 2>&1 || . "${TEST_ENV:=tools/ci/env.sh}"
# Fallback func-name to init namespace to avoid overlap with builtin names
main_ "init" "$@"
