
pd_register grunt init test

pd__grunt_autoconfig()
{
  test -x "$(which grunt 2>/dev/null)" || return 1
  test -e "$(echo Gruntfile*|head -n 1 2>/dev/null )" \
    || return 1
}

pd_init__grunt_autoconfig()
{
  pd__grunt_autoconfig && {
    # TODO: targets
    note "Using grunt init-package"
    echo ":grunt:init-package"
  } || return 0
}

pd_test__grunt_autoconfig()
{
  pd__grunt_autoconfig && {
    # XXX: should really check for metadata, consolidate first
    note "Using grunt test"
    echo ":grunt:test"
  } || return 0
}


pd__grunt_init_package()
{
  echo
}


pd_load__grunt_test=i
pd__grunt_test()
{
  grunt test || return $?
}



