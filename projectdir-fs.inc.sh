
pd_register fs check


pd_check__fs_autoconfig()
{
  return
  echo ":fs:names"
  echo ":fs:clean"
}


pd_load__fs_clean=i
pd__fs_clean()
{
  mkid "fs:clean:TODO:$@"
  echo "$id" >> $skipped
}


pd_load__fs_names=i
pd__fs_names()
{
  mkid "fs:names:TODO:$@"
  echo "$id" >> $skipped
}

