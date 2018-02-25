#!/usr/bin/env bats

load init

test_import()
{
  python -c "from script_mpe import res"
  python -c "from script_mpe import taxus"
}

@test "test_import" {

  run $BATS_TEST_DESCRIPTION
  test ${status} -eq 0
  test ${#lines[@]} -eq 0 || fail "Python module(s) writing stdout/err"
  test "${lines[*]}" = ""

  tmpf
  $BATS_TEST_DESCRIPTION >$tmpf 2>&1
  test -s "$tmpf" && fail "If this fails expected above to fail too. Check bats. " || noop
}


test_import_2()
{
  python -c "from script_mpe import res"
  python -c "from script_mpe import taxus"
}

@test "test_import_2" {

  run $BATS_TEST_DESCRIPTION
  test ${status} -eq 0
  test ${#lines[@]} -eq 0 || fail "Python module(s) writing stdout/err"
  test "${lines[*]}" = ""

  tmpf
  $BATS_TEST_DESCRIPTION 1>$tmpf 2>&1
  test -s "$tmpf" && fail "If this fails expected above to fail too. Check bats. " || noop
}
