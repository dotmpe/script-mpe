# See meta.lib

metadir_lib__load ()
{
  : "${metadirs_default:="\{,.}meta"}"
}

metadir_lib__init ()
{
  local found=false
  test -n "${metadir_default:-}" || {
    for metadir_default in $(eval echo ${metadirs_default:?})
    do
      test -e "$metadir_default" && { found=true; break; }
    done
  }
  $found || test -e "$metadir_default"
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
