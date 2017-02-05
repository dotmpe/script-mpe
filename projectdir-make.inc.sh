
pd_register make init test


pd_init__make_autoconfig()
{
  test -x "$(which make 2>/dev/null)" || return 1
  test -e Makefile && {
    # TODO: targets
    note "Using make init-package"
    echo ":make:init-package"
  }
  return 0
}

pd_test__make_autoconfig()
{
  test -e Makefile && {
    # XXX: should really check for metadata, consolidate first
    note "Using make test"
    echo ":make:test"
  }
  return 0
}


pd__make_test()
{
  echo make test || return $?
}
pd_load__make_test=i


pd__make()
{
  test -n "$1" || set -- stat

  local result=0

  make "$@" || result=$?

  #local pd_reportsh="$(eval echo "\"\$$(try_local make reportsh)\"")"
  #test -e "$pd_reportsh" && {
  #  states="$(cat $pd_reportsh)"
  #}

  return $result
}
pd_load__make=i
pd_reportsh__make=.build/pd-make-states.sh



