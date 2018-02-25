#!/usr/bin/env bats

base=htd
load init
init
pwd=$(cd .;pwd -P)


version=0.0.4-dev # script-mpe

setup() {
  scriptname=test-$base
  . ./tools/sh/init.sh
  lib_load projectenv env-deps
}

@test "$bin tpaths - prints paths to definition-list terms" {

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
    $bin tpaths $@ 2>/dev/null
  }
  run _test test.rst

  test $status -eq 0 || fail "Output: ${lines[*]}"

  check_skipped_envs travis ||
    skip "'$bin $tpaths' not running at Linux (Travis)"

  test "${lines[0]}" = "/Dev/Software" || fail "Output: ${lines[*]}"
  #skip "TODO: fixme tpaths is failing"
  test "${lines[1]}" = "/Dev/Hardware" || fail "Output: ${lines[*]}"
  test "${lines[2]}" = "/Personal/Topic" || fail "Output: ${lines[*]}"
  test "${lines[3]}" = "/Public/Note" || fail "Output: ${lines[*]}"
}


@test "$bin tpaths - prints paths to definition-list terms with special characters" {

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
    $bin tpaths $@ 2>/dev/null
  }
  run _test test.rst

  test $status -eq 0 || fail "Output: ${lines[*]}"

  check_skipped_envs travis || \
    skip "'$bin tpaths' not running at Linux (Travis)"

  test "${lines[0]}" = "/Dev/Software" \
    || fail "Output: ${lines[*]}"
  test "${lines[1]}" = "/Dev/Hardware" \
    || fail "Output: ${lines[*]}"
  test "${lines[2]}" = "/Personal/\"Topic Title\"/\"Another Title\""
  test "${lines[3]}" = "/Public/Note"
}

@test "$bin tpath-raw - prints paths to definition-list terms" {

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

  run $bin tpath-raw test.rst

  check_skipped_envs travis || \
    skip "'$tpath-raw' not testing at Linux (Travis)"

  l=$(( ${#lines[*]} - 1 ))
  diag "${lines[$l]}"
  test "${lines[$l]}" = \
    "/Dev/Software/../Hardware/../../Personal/../Public/Note/../.."
}


@test "$bin tpath-raw - prints paths to definition-list terms" {

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

  run $bin tpath-raw test.rst

  check_skipped_envs travis || \
    skip "'$bin tpath-raw' not testing at Linux (Travis)"

  l=$(( ${#lines[*]} - 1 ))
  test "${lines[$l]}" = '/Dev/../Home/Shop/../Living/../../Public/Topic/../..' \
    || fail "Output: ${lines[*]}"
}


@test "$bin tpath-raw - v2 prints paths to definition-list terms with spaces and other chars" {

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
  run $bin tpath-raw test.rst

  check_skipped_envs travis || \
    skip "'$bin tpath-raw' not testing at Linux (Travis)"

  l=$(( ${#lines[*]} - 1 ))
  diag "Lines: ${lines[*]}"
  test "${lines[$l]}" = '/"Soft Dev"/../Home/Shop/"Electric Tools"/../../"Living Room"/../../Public/"Topic Note"/../..'
}
