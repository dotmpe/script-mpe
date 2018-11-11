#!/usr/bin/env bats

load init
base=__base__

setup()
{
  {
    echo 'Env:'; env; echo; echo 'Set:'; set
  } > _tmp/bats-env1

  #. ./test/var/sh-src-main-mytest-funcs.sh
}

init

@test "$base: foo" {
  true
}
