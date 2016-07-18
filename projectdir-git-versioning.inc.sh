
pd_register git-versioning check


pd_check__git_versioning_autoconfig()
{
  test -e .versioned-files.list && {
    echo git-versioning
  }
}


