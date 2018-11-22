#!/usr/bin/env bats

load init
base=htd-git
init

@test "$base: help" {
  run htd help git
  test_ok_nonempty || stdfail
}

@test "$base: info compiles repo list from \$PROJECTS" {

  tmpd && mkdir "$tmpd/index"
  export STATUSDIR_ROOT=$tmpd
  run htd git info
  { test_ok_nonempty && test_lines \
    "*OK, * vendors*" \
    "*OK, * users and teams*" \
    "*OK, * repositories*" &&
    test -e "$tmpd/index/git-src.list"
  } || stdfail
  rm -rf "$tmpd"
}
