
pd_register make init test


pd_init__make_autoconfig()
{
  test -e Makefile && {
    # TODO: targets
    note "Using make init-package"
    echo ":make:init-package"
  }
}

pd_test__make_autoconfig()
{
  test -e Makefile && {
    # XXX: should really check for metadata, consolidate first
    note "Using make test"
    echo ":make:test"
  }
}

