metadir_lib_load ()
{
  : "${metadirs_default:={,.}meta}"
  : "${metadir_default:=.meta}"
}


metadir_basedirs () # ~ <Paths...>
{
  foreach "${@:?}" | foreach_line_do fs_basedir_with ${metadir_default:?}
}

# XXX: find dir with marker leaf. See os.lib:go_to_dir_with.
fs_basedir_with () # ~ <Sub> <Path>
{
  local path=${2:?}
  while test "$path" != "/"
  do
    test -e "$path/${1:?}" && {
      echo "$path"
      return
    }
    path=$(dirname "$path")
  done
  return 1
}

#
