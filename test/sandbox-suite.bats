#!/usr/bin/env bats


@test "Entire suite at sandbox" {

  skip "TODO: fix running remotely in sandbox"

  ssh -p 28022 localhost whoami || skip "Sandbox missing"

  for name in helper std str os main util-lib meta sh vc box box-lib
  do
    ssh -p 28022 localhost "cd \$HOME/bin && bats ./test/${name}-spec.bats" \
      && diag "Passed: $name" \
      || fail "Failed: $name"
  done
}

