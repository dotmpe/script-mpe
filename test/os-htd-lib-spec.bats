#!/usr/bin/env bats

load init
setup ()
{
  #set -eu
  . ./os-htd.lib.sh
}

@test os-normalize {
  tests=(
    "from/here/to/../../there"
    "./../and/./below/."
    "./some/././/.//where///"
    "/and/.hidden/some/../../another/not-hidden"
    ".meta/stat/index/../../../cabinet/.meta/stat/index/context-backup.list"
  )
  expected=(
    "from/there"
    "../and/below"
    "some/where/"
    "/and/another/not-hidden"
    "cabinet/.meta/stat/index/context-backup.list"
  )

  for i in "${!tests[@]}"
  do
    assert_equal "$(os_normalize "${tests[i]}")" "${expected[i]}"
  done
}

#
