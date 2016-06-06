#!/usr/bin/env bats

load helper
base=projectdir-meta

init
. $lib/util.sh


@test "${bin}" "default no-args" {
  run $BATS_TEST_DESCRIPTION
  test ${status} -eq 1
}


@test "${bin} help" {
  run $BATS_TEST_DESCRIPTION
  test ${status} -eq 1
  fnmatch "Usage:*" "${lines[*]}"
}


# XXX: see mod_pd_meta.py
@test "${bin} clean-mode" {
  cd $tmpd
{
  cat - <<EOM
repositories:
  myPrefix1: {}
  myPrefix2:
    clean: tracked
  myPrefix3:
    clean: excluded
EOM
} > .projects.yaml
# Get mode
  run $BATS_TEST_DESCRIPTION myPrefix1
  test "${lines[*]}" = "untracked"
  test ${status} -eq 0
  run $BATS_TEST_DESCRIPTION myPrefix2
  test "${lines[*]}" = "tracked"
  test ${status} -eq 0
  run $BATS_TEST_DESCRIPTION myPrefix3
  test "${lines[*]}" = "excluded"
  test ${status} -eq 0
# Check mode
  run $BATS_TEST_DESCRIPTION myPrefix1 excluded
  test ${status} -eq 1
  test -z "${lines[*]}"
  run $BATS_TEST_DESCRIPTION myPrefix2 excluded
  test -z "${lines[*]}"
  test ${status} -eq 1
  run $BATS_TEST_DESCRIPTION myPrefix3 excluded
  test -z "${lines[*]}"
  test ${status} -eq 0
# Check mode (strict)
  run projectdir-meta -s clean-mode myPrefix1 excluded
  test -z "${lines[*]}"
  test ${status} -eq 1
  run projectdir-meta -s clean-mode myPrefix2 excluded
  test -z "${lines[*]}"
  test ${status} -eq 1
  run projectdir-meta -s clean-mode myPrefix3 excluded
  test -z "${lines[*]}"
  test ${status} -eq 0
# Check mode (quiet)
# Check mode (quiet+strict)
}



