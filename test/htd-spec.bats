#!/usr/bin/env bats

base=htd
load helper
init_bin

version=0.0.0

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
  test "${#lines[@]}" = "10"
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
  run $BATS_TEST_DESCRIPTION
  test $status -eq 0
  test "${lines[0]}" = "$version"
}

@test "$bin rewrite and test to new main.sh" {
  check_skipped_envs || \
    skip "TODO envs $envs: implement bin for env"
  #run $BATS_TEST_DESCRIPTION
  #test $status -eq 0
  #test "${#lines[@]}" = "9"
  #test -z "${lines[*]}" # empty output
}

# vim:ft=sh:
