#!/usr/bin/env bats

base=htd
load init
init
pwd=$(cd .;pwd -P)


version=0.0.4-dev # script-mpe

setup() {
  scriptname=test-$base

  type require_env >/dev/null 2>&1 && {
    #. $ENV
    . ./tools/sh/init.sh
    lib_load projectenv env-deps
  } || {
    . ./tools/ci/env.sh
    project_env_bin node npm lsof
  }
}

@test "$bin no arguments no-op" {
  skip "Default command is $EDITOR now"
  run $bin
  test ${status} -eq 2
  fnmatch "*htd*No command given*" "${lines[*]}"
}

@test "$bin help" {
  run $BATS_TEST_DESCRIPTION
  test $status -eq 0
}

@test "$bin version" {
  export verbosity=0 DEBUG=
  run $BATS_TEST_DESCRIPTION
  test $status -eq 0
  fnmatch "*script-mpe/$version (htd)*" "${lines[*]}" ||
    fail "Expected script-mpe/$version" 
}

@test "$bin home" {
 
  OLDPWD=$PWD

  cd $TMPDIR

  check_skipped_envs travis \
  || TODO "envs $envs: implement $BATS_TEST_DESCRIPTION for env"

  _test() {
    $BATS_TEST_DESCRIPTION 2>/dev/null
  }
  run _test
  test $status -eq 0

  test -n "$HTDIR" || HTDIR="$(echo ~/public_html)"
  test "${lines[0]}" = "$HTDIR" \
    || fail "${lines[0]} != $HTDIR"

  case "$(current_test_env)" in

    simza )

      test ! -d ~/public_html
      mkdir ~/public_html
      ;;

    travis )
      ;;

  esac

  TODO "fix rest of test"
  run bash -c "_test() { $BATS_TEST_DESCRIPTION 2>/dev/null; } ; export HTDIR= && _test"
  test "${lines[*]}" = "$(echo ~/public_html)"

  case "$(current_test_env)" in

    simza )

      rm -r ~/public_html
      ;;

  esac

  cd $PWD
}

@test "$bin info" {
  run $BATS_TEST_DESCRIPTION
  test $status -eq 0
  test "${#lines[@]}" -ge 12
  fnmatch "*id: script-mpe*" "${lines[*]}"
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
  test $status -eq 0
  run ${bin} check-names pathlist2dot-default-template.py
  test $status -eq 0
  run ${bin} check-names dataurl.py
  test $status -eq 0
  # TODO: fix check-names
  #run ${bin} check-names dataurl.py filenames-ext,python-module,python-script,std-ascii
  #test $status -eq 0
  #run ${bin} check-names ANSI-shell-coloring.py* filenames-ext,python-script,std-ascii
  #test $status -eq 0
}

@test "$bin today" {

  skip "FIXME journal dir is now set best-effort"
  cd $BATS_TMPDIR

  test ! -d bats-test-log || rm -rf bats-test-log

  mkdir bats-test-log
  _test() {
    $BATS_TEST_DESCRIPTION bats-test-log/ 2>/dev/null
  }
  run _test
  test $status -eq 0
  test "${#lines[@]}" -ge "24"

  for x in today tomorrow yesterday \
    monday tuesday wednesday thursday friday saturday sunday
  do
    test -h $BATS_TMPDIR/bats-test-log/${x}.rst
  done
  # XXX may also want to check last-saturday, next-* etc.
  #   also, may want to have larger offsets and wider time-windows: months, years

  rm -rf bats-test-log
  rm -rf journal || noop

  run $BATS_TEST_DESCRIPTION
  test $status -eq 1

  fnmatch "*Error*Dir *$BATS_TMPDIR/journal must exist*" "${lines[*]}"
}

@test "$bin rewrite and test to new main.lib.sh" {
  check_skipped_envs || \
    TODO "envs $envs: implement bin for env"
  #run $BATS_TEST_DESCRIPTION
  #test $status -eq 0
  #test "${#lines[@]}" = "9"
  #test -z "${lines[*]}" # empty output
}

@test "$bin check-disks" {
  test "$(uname)" = "Linux" && skip "check-disks Linux"
  case "$hostname" in boreas* ) skip "Boreas";; esac
  run $BATS_TEST_DESCRIPTION
  test ${status} -eq 0
  fnmatch "Path*OK*" "${lines[*]}"
}

@test "$bin ck-init" {

  skip "FIXME: boreas"
  tmpd
  mkdir -p $tmpd/foo
  echo baz > $tmpd/foo/bar
  cd $tmpd
  run $BATS_TEST_DESCRIPTION
  {
    test ${status} -eq 0 &&
    fnmatch "*Adding dir '.'*" "${lines[*]}" &&
    fnmatch "*ck-init*Adding dir '.'*" "${lines[*]}" &&
    fnmatch "*ck-init*Updated CK table 'table.ck'*" "${lines[*]}"
  } || 

    fail "Status: $status; Output: ${lines[*]}"
}

@test "$bin update (ck-prune, ck-clean, ck-update)" {
  skip "Deprecated"
  run $bin update
  rm table.*missing || noop
  git checkout table.*
  test ${status} -eq 0 ||
    fail "Status: $status; Output: ${lines[*]}"
}


# Std journal path: journal/today.rst -> journal/%Y-%d-%m.rst

@test "$bin archive-path journal" {
  tmpd
  mkdir -p $tmpd/journal
  cd $tmpd
  export EXT=.rst
  run $BATS_TEST_DESCRIPTION
  dl=$tmpd/journal/today.rst
  {
    test ${status} -eq 0 &&
    test -h "$dl"
    # FIXME: test "$(readlink $dl)" = 2016/12/30.rst
  } || {
    diag "Output: ${lines[*]}"
    diag "Link: $dl"
    diag "Target: $(readlink "$dl")"
    fail "$BATS_TEST_DESCRIPTION ($status)"
  }
}

#@test "$bin archive-path journal" {
#  tmpd
#  cd $tmpd
#  run $BATS_TEST_DESCRIPTION
#  test ${status} -ne 0 || {
#    diag "Output: ${lines[*]}"
#    fail "$BATS_TEST_DESCRIPTION ($status)"
#  }
#}


# Adjusted for cabinet
#   cabinet/today -> cabinet/%Y/%d/%m
@test "$bin archive-path cabinet" {
  skip 'TODO: fix archive basename link'
  tmpd
  mkdir -p $tmpd/cabinet
  cd $tmpd
  export EXT= M=/%m D=/%d 
  run $BATS_TEST_DESCRIPTION
  dl=$tmpd/cabinet/today
  {
    test ${status} -eq 0 &&
    test -h "$dl" &&
    test "$(readlink $dl)" = 2016/12/30
  } || {
    diag "Output: ${lines[*]}"
    diag "Link: $dl"
    diag "Target: $(readlink "$dl")"
    fail "$BATS_TEST_DESCRIPTION ($status)"
  }
}


@test "$bin run - runs 'scripts names'" {
  export verbosity=0
  local tmp=/tmp/htd-script-names-$(uuidgen)
  local tmp2=/tmp/htd-script-names-$(uuidgen)

  run $bin run
  test_nok_nonempty || stdfail 1
  echo "${lines[@]}" >> $tmp

  run $bin scripts names
  test_ok_nonempty || stdfail 2
  echo "${lines[@]}" >> $tmp2

  diff $tmp $tmp2 || {
    rm $tmp $tmp2
    fail
  }
}


@test "$bin scripts names - list script names" {
  run $bin scripts names
  { test_ok_nonempty &&
    fnmatch *" check "* " ${lines[*]} " &&
    fnmatch *" build "* " ${lines[*]} " &&
    fnmatch *" test "* " ${lines[*]} "
  } || stdfail
}


@test "$bin scripts list - gives script outline (list indented script names and lines)" {
  run $bin scripts list
  { test_ok_nonempty &&
    fnmatch *" check "* " ${lines[*]} " &&
    fnmatch *" build "* " ${lines[*]} " &&
    fnmatch *" test "* " ${lines[*]} "
  } || stdfail
}


@test "$bin open" {
  require_env lsof
  run $BATS_TEST_DESCRIPTION
  test_ok_nonempty || stdfail
}

@test "$bin open-paths" {
  require_env lsof
  run $BATS_TEST_DESCRIPTION
  test_ok_nonempty || stdfail
}

@test "$bin current-paths" {
  require_env lsof
  run $BATS_TEST_DESCRIPTION
  test_ok_nonempty || stdfail
}

@test "$bin topics list has output, no error" {
  run $bin topics list
  test_ok_nonempty || stdfail
}

@test "$bin package - prints, no error" {
  run $bin package
  test_ok_nonempty || stdfail
}

@test "$bin env pathvars" {
  run $bin env pathvars
  test_ok_lines "PATH=*" || stdfail
}

@test "$bin env dirvars" {
  run $bin env dirvars
  test_ok_lines "PWD=*" "TMPDIR=*" || stdfail
}

@test "$bin env filevars" {
  run $BATS_TEST_DESCRIPTION
  test_ok_lines "SHELL=*" "ENV=*" "LOG=*" || stdfail
}

@test "$bin env symlinkvars" {
  export verbosity=0
  run $BATS_TEST_DESCRIPTION
  test_ok_empty || stdfail
}


#@test "${lib}/${base} - function should ..." {
#  check_skipped_envs || \
#    TODO "envs $envs: implement lib (test) for env" # tasks-ignore
#  diag
#  run function args
#  test true || fail
#  test_ok_empty || stdfail
#  test_ok_nonempty || stdfail
#  test_ok_nonempty "*match*" || stdfail
#  { test_nok_nonempty "*match*" &&
#    test ${status} -eq 1 &&
#    fnmatch "*other*" &&
#    test ${#lines[@]} -eq 3
#  } || stdfail
#}
