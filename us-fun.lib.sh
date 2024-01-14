
us_fun_lib__load ()
{
  lib_require sys basedir-htd metadir lib-uc
}

at_ () # ~ <ctx> [<ctx|args..>]
{
  while test 0 -lt $#
  do
    : "${1:?at_ argument 1 expected}"

    ctxv=${1//[^A-Za-z0-9_]/_}ctx
    test -n "${!ctxv:-}" &&
    std_quiet declare -F "$_" && {
      set -- $_ "${@:2}"
      break
    }

    uc_script_load "${1:?}" || return
    ! std_quiet declare -F at_${1//[^A-Za-z0-9_]/_} || {
      set -- $_ "${@:2}"
      break
    }
    shift
  done
  test 0 -eq $# && return
  "$@"
}

us_basedir_init ()
{
  lib_uc_initialized basedir-htd || return
  declare -g bd
  if_ok "$(cwd_lookup_paths)" &&
  for bd in $_
  do
    sym=$($basedirtab.key-by-index 1 "$bd/" 2) || continue
    break
  done &&
    $LOG info "" "Found basedir '$sym'" "$PWD:$sym=$bd/" ||
    $LOG warn "" "No basedir" "E$?:$PWD" $?
}

us_metadir_init ()
{
  lib_uc_initialized metadir || return
  test -d "${SD_LOCAL-}" && return
  TODO "Find SD-Local on CWD"
}

us_stbtab_init ()
{
  create stbtab StatTab "${STTAB:?}" ||
    $LOG error : "Failed to load stattab index" "E$?:$STTAB" $? || return
}

#
