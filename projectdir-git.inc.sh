
pd_register git init check sync test


pd_init__git_autoconfig()
{
  test -d .git && echo git:hooks
  return 0
}

pd_check__git_autoconfig()
{
  test -d .git && echo git:check
  return 0
}

pd_test__git_autoconfig()
{
  test -d .git && echo git:clean
  return 0
}


pd_load__git_check=i
pd__git_check()
{
  note "TODO $subcmd $@"
}

