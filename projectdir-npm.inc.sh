
pd_register npm init check test


pd_init__npm_autoconfig()
{
  test -e package.json && {
    # TODO: load data, may want to run check for target first.
    note "Using npm init-package"
    echo ":npm:init-package"
  }
}

pd_check__npm_autoconfig()
{
  test -e package.json && {
    # XXX: should really check for metadata, consolidate first
    note "Using npm check-package"
    echo ":npm:check-package"
  }
}

pd_test__npm_autoconfig()
{
  test -e package.json && {
    # XXX: should really check for metadata, consolidate first
    note "Using npm test"
    echo ":npm:test"
  }
}


