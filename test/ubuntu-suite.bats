#!/usr/bin/env bats


@test "Entire suite at ubuntu" {

  cd tools/ci/vbox

  vagrant ssh ubuntu -c whoami || skip "Ubuntu VM missing"

  # FIXME: helper needs env.
  for name in helper std str os main util-lib meta sh vc box box-lib
  do
    vagrant ssh ubuntu -c "export PRECISE64_SKIP=1 ; cd /vagrant; ~/.local/bin/bats ./test/$name-spec.bats" \
      && diag "Passed: $name" \
      || fail "Failed: $name"
  done

}


