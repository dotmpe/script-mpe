
pd_register git init check sync test


pd_init__git_autoconfig()
{
  test -d .git && echo git:hooks
}

pd_check__git_autoconfig()
{
  test -d .git && echo git:check
}

pd_test__git_autoconfig()
{
  test -d .git && echo git:clean
}


pd__git_check()
{
  note "TODO $subcmd $@"
}

