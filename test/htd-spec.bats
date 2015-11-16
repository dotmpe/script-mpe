#!/usr/bin/env bats

base=htd
load helper
init
source $lib/util.sh
source $lib/str.sh


version=0.0.0+20150911-0659 # script.mpe

@test "$bin no arguments no-op" {
  run $bin
  test $status -eq 1
  echo "${#lines[@]}" > /tmp/1
  test "${#lines[@]}" = "4"
}

@test "$bin help" {
  run $BATS_TEST_DESCRIPTION
  test $status -eq 0
}

@test "$bin home" {
  run $BATS_TEST_DESCRIPTION
  test $status -eq 0
  test -n "$HTDIR" || HTDIR="$(echo ~/public_html)"
  test "${lines[0]}" = "$HTDIR"

  run bash -c "HTDIR= $BATS_TEST_DESCRIPTION"
  test "${lines[0]}" = "$(echo ~/public_html)"
}

@test "$bin  info" {
  run $BATS_TEST_DESCRIPTION
  test $status -eq 0
  #echo "${lines[@]}" > /tmp/1
  #echo "${#lines[@]}" >> /tmp/1
  test "${#lines[@]}" = "12"
}

@test "$bin test-name" {
  run ${bin} test-name ./linux-network-interface-cards.py
  test $status -eq 0
  run ${bin} test-name "./Foo Bar Baz/"
  test $status -eq 0
  run ${bin} test-name "./Foo + Bar & Baz/"
  test $status -eq 0
  run ${bin} test-name "./(Foo) Bar [Baz]/"
  test $status -eq 0
}

@test "$bin check-names filenames with table.{vars,names}" {
  skip "FIXME htd check-names"
  run ${bin} check-names 256colors2.pl
  #test "${lines[1]}" = "# Loaded $HOME/bin/table.vars"
  #test "${lines[2]}" = "No match for 256colors2.pl"
  #test "${lines[3]}" = "# (eof) "
  #test "${#lines[@]}" = "4"
  test $status -eq 0
  run ${bin} check-names pathlist2dot-default-template.py
  test $status -eq 0
  run ${bin} check-names dataurl.py
  test $status -eq 0
  run ${bin} check-names dataurl.py filenames-ext,python-module,python-script,std-ascii
  test $status -eq 0
  run ${bin} check-names ANSI-shell-coloring.py* filenames-ext,python-script,std-ascii
  test $status -eq 0
}

@test "$bin version" {
  check_skipped_envs travis || skip "$BATS_TEST_DESCRIPTION not running at Travis CI"
  run $BATS_TEST_DESCRIPTION
  test $status -eq 0
  test "${lines[0]}" = "script.mpe/$version"
}

@test "$bin today" 8 {

  tmp="$(cd /tmp/; pwd -P)"
  cd "$tmp"
  test ! -d bats-test-log || rm -rf bats-test-log

  mkdir bats-test-log
  run $BATS_TEST_DESCRIPTION bats-test-log/
  test $status -eq 0
  #echo "${lines[*]}" > /tmp/1
  #echo "${#lines[@]}" >> /tmp/1
  test "${#lines[@]}" = "24"

  for x in today tomorrow yesterday \
    monday tuesday wednesday thursday friday saturday sunday
  do
    test -h $tmp/bats-test-log/${x}.rst
  done
  # XXX may also want to check last-saturday, next-* etc.
  #   also, may want to have larger offsets and wider time-windows: months, years

  rm -rf bats-test-log
  run $BATS_TEST_DESCRIPTION
  test $status -eq 1
  fnmatch "*Error*Dir journal must exist*" "${lines[*]}"
  test "${#lines[@]}" = "1"
}

@test "$bin rewrite and test to new main.sh" {
  check_skipped_envs || \
    skip "TODO envs $envs: implement bin for env"
  #run $BATS_TEST_DESCRIPTION
  #test $status -eq 0
  #test "${#lines[@]}" = "9"
  #test -z "${lines[*]}" # empty output
}

