#!/usr/bin/env bats

base=htd
load helper
init
pwd=$(cd .;pwd -P)


version=0.0.4-dev # script-mpe

setup() {
  scriptname=test-$base
  . $ENV
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
  fnmatch "*Script:*" "${lines[*]}"
  fnmatch "*Editor:*" "${lines[*]}"
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
  check_skipped_envs travis || skip "$BATS_TEST_DESCRIPTION not running at Travis CI"
  export verbosity=5
  run $BATS_TEST_DESCRIPTION
  test $status -eq 0
  test "${lines[0]}" = "htdocs-mpe/$version" ||
    fail "Expected htdocs-mpe/$version" 
}

@test "$bin today" 8 {

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


@test "$bin tpaths" "prints paths to definition-list terms" {

  cd $BATS_TMPDIR

  {
    cat - <<EOM
Dev
  Software
    ..
  Hardware
    ..
Personal
  Topic
    ..
Public
  Note
    ..
EOM
} > test.rst

  _test() {
    $BATS_TEST_DESCRIPTION $@ 2>/dev/null
  }
  run _test test.rst

  test $status -eq 0 || fail "Output: ${lines[*]}"

  check_skipped_envs travis || \
    skip "$BATS_TEST_DESCRIPTION not running at Linux (Travis)"

  test "${lines[0]}" = "/Dev/Software" || fail "Output: ${lines[*]}"
#skip "TODO: fixme tpaths is failing"
  test "${lines[1]}" = "/Dev/Hardware" || fail "Output: ${lines[*]}"
  test "${lines[2]}" = "/Personal/Topic" || fail "Output: ${lines[*]}"
  test "${lines[3]}" = "/Public/Note" || fail "Output: ${lines[*]}"
}


@test "$bin tpaths" "prints paths to definition-list terms with special characters" {

  test "$(uname)" = "Linux" && skip "Fix XSLT v2 at Linux"

  cd $BATS_TMPDIR

  {
    cat - <<EOM
Dev
  Software
    ..
  Hardware
    ..
Personal
  Topic Title
    Another Title
      ..
Public
  Note
    ..
EOM
} > test.rst

  export xsl_ver=2 
  _test() {
    $BATS_TEST_DESCRIPTION $@ 2>/dev/null
  }
  run _test test.rst

  test $status -eq 0 || fail "Output: ${lines[*]}"

  check_skipped_envs travis || \
    skip "$BATS_TEST_DESCRIPTION not running at Linux (Travis)"

  test "${lines[0]}" = "/Dev/Software" \
    || fail "Output: ${lines[*]}"
  test "${lines[1]}" = "/Dev/Hardware" \
    || fail "Output: ${lines[*]}"
  test "${lines[2]}" = "/Personal/\"Topic Title\"/\"Another Title\""
  test "${lines[3]}" = "/Public/Note"
}

@test "$bin tpath-raw" "prints paths to definition-list terms" {

  cd $BATS_TMPDIR
  {
    cat - <<EOM
Dev
  Software
    ..
  Hardware
    ..
Personal
  ..
Public
  Note
    ..
EOM
} > test.rst

  run $BATS_TEST_DESCRIPTION test.rst

  check_skipped_envs travis || \
    skip "$BATS_TEST_DESCRIPTION not testing at Linux (Travis)"

  l=$(( ${#lines[*]} - 1 ))
  diag "${lines[$l]}"
  test "${lines[$l]}" = \
    "/Dev/Software/../Hardware/../../Personal/../Public/Note/../.."
}


@test "$bin tpath-raw" "prints paths to definition-list terms" {

  cd $BATS_TMPDIR
  {
    cat - <<EOM
Dev
  ..
Home
  Shop
    ..
  Living
    ..
Public
  Topic
    ..
EOM
} > test.rst

  run $BATS_TEST_DESCRIPTION test.rst

  check_skipped_envs travis || \
    skip "$BATS_TEST_DESCRIPTION not testing at Linux (Travis)"

  l=$(( ${#lines[*]} - 1 ))
  test "${lines[$l]}" = '/Dev/../Home/Shop/../Living/../../Public/Topic/../..' \
    || fail "Output: ${lines[*]}"
}


@test "$bin tpath-raw" "v2 prints paths to definition-list terms with spaces and other chars" {

  test "$(uname)" = "Linux" && skip "Fix XSLT v2 at Linux"

  cd $BATS_TMPDIR
  {
    cat - <<EOM
Soft Dev
  ..
Home
  Shop
    Electric Tools
      ..
  Living Room
    ..
Public
  Topic Note
    ..
EOM
} > test.rst

  export xsl_ver=2 
  run $BATS_TEST_DESCRIPTION test.rst

  check_skipped_envs travis || \
    skip "$BATS_TEST_DESCRIPTION not testing at Linux (Travis)"

  l=$(( ${#lines[*]} - 1 ))
  diag "Lines: ${lines[*]}"
  test "${lines[$l]}" = '/"Soft Dev"/../Home/Shop/"Electric Tools"/../../"Living Room"/../../Public/"Topic Note"/../..'
}


@test "$bin check-disks" {
  test "$(uname)" = "Linux" && skip "check-disks Linux"
  case "$hostname" in boreas* ) skip "Boreas";; esac
  run $BATS_TEST_DESCRIPTION
  test ${status} -eq 0
  fnmatch "Path*OK*" "${lines[*]}"
}

@test "$bin ck-init" {
  tmpd
  mkdir -p $tmpd/foo
  echo baz > $tmpd/foo/bar
  cd $tmpd
  run $BATS_TEST_DESCRIPTION
  {
    test ${status} -eq 0
    fnmatch "*Adding dir '.'*" "${lines[*]}"
    fnmatch "*ck-init*Adding dir '.'*" "${lines[*]}"
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


@test "$bin archive-path journal/" "non-zero exit" {
  tmpd
  cd $tmpd
  run $BATS_TEST_DESCRIPTION
  test ${status} -ne 0 || {
    diag "Output: ${lines[*]}"
    fail "$BATS_TEST_DESCRIPTION ($status)"
  }
}


# Adjusted for cabinet
#   cabinet/today -> cabinet/%Y/%d/%m
@test "$bin archive-path cabinet" "EXT= M=/%m D=/%d" {
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


@test "$bin run - runs subcmd run-dir" {
  run $bin run
  test_ok_nonempty || stdfail
}


@test "$bin run-names - list script names" {
  run $bin run-names
  { test_ok_nonempty &&
    fnmatch *" check "* " ${lines[*]} " &&
    fnmatch *" build "* " ${lines[*]} " &&
    fnmatch *" test "* " ${lines[*]} "
  } || stdfail
}


@test "$bin run-dir - gives script outline (list indented script names and lines)" {
  run $bin run-dir
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

@test "$bin prefixes" {
  require_env lsof
  run $BATS_TEST_DESCRIPTION
  test_ok_nonempty || stdfail
}

@test "$bin prefix-names" {
  require_env lsof
  run $BATS_TEST_DESCRIPTION
  test_ok_nonempty || stdfail
}

@test "$bin prefix-name" {
  run $BATS_TEST_DESCRIPTION
  test_ok_nonempty || stdfail
}

@test "$bin path-prefix-names" {
  run $bin path-prefix-names
  test_ok_nonempty || stdfail
}


@test "$bin topics-list" {
  run $BATS_TEST_DESCRIPTION
  test_ok_nonempty || stdfail
}


@test "$bin package" {
  run $bin package
  test_ok_nonempty || stdfail
}

