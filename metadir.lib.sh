metadir_lib__load ()
{
  lib_require os-htd stattab-uc || return

  : "${metadirs_default:="\{,.}meta"}"
  : "${METADIRS_TAB:=${STATUSDIR_ROOT:?}index/metadirs.tab}"
}

metadir_lib__init ()
{
  test -z "${metadir_lib_init-}" || return $_
  test -n "${metadir_default:-}" || {
    for metadir_default in $(eval echo ${metadirs_default:?})
    do
      ! test -e "$metadir_default" || break
    done
  }
  test -e "$metadir_default" || return
  test ! -e "$metadir_default/stat" || : "${SD_LOCAL:=$_}"
  test ! -e "$metadir_default/cache" || : "${LCACHE_DIR:=$_}"
  #create metadirs StatTab $METADIRS_TAB
  #$LOG info :metadir.lib:init "Loaded" "E$?" $?
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
