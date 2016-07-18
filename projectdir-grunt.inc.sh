
pd_register grunt init test

pd__grunt_autoconfig()
{
  test -e "$(echo Gruntfile*|head -n 1 2>/dev/null )" \
    || return 1
}

pd_init__grunt_autoconfig()
{
  pd_init__grunt_autoconfig && {
    # TODO: targets
    note "Using grunt init-package"
    echo ":grunt:init-package"
  }
}

pd_test__grunt_autoconfig()
{
  pd_init__grunt_autoconfig && {
    # XXX: should really check for metadata, consolidate first
    note "Using grunt test"
    echo ":grunt:test"
  }
}


pd__grunt_init_package()
{
  echo
}

