#!/usr/bin/env bats


@test "Entire suite at ubuntu" {

  cd tools/ci/vbox

  vagrant ssh ubuntu -c whoami || skip "Ubuntu VM missing (cd tools/ci/vbox && vagrant up)"

  # FIXME: helper needs env. should provision tools/ci/vbox for this
  for name in helper std str main util-lib meta sh vc box box-lib
  # FIXME: os
  do
    vagrant ssh ubuntu -c "export PRECISE64_SKIP=1 ; cd /vagrant; ~/.local/bin/bats ./test/${name}-spec.bats" \
      && diag "Passed: $name" \
      || fail "$name"
  done

}

