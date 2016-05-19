#!/usr/bin/env bats

load helper
base=projectdir.sh

init
. $lib/util.sh


setup_projdir()
{
  tmpd
  { cat <<EOF
repositories:
  user-conf:
    default: dev
    disabled: true
    remotes:
      origin: https://github.com/dotmpe/user-conf.git
    sync: true
    clean: untracked
EOF
  } > $tmpd/.projects.yaml
}


@test "Pd use-case 1: enable, disable a checkout without errors" {
  setup_projdir
  test -s $tmpd/.projects.yaml
  cd $tmpd 
  pd enable user-conf
  pd clean user-conf
  pd disable user-conf
}


@test "Pd use-case 2: tell about a prefix" {
  setup_projdir
  test -s $tmpd/.projects.yaml
  pd show user-conf
}

# vim:ft=bash:
