
### Playlist util


ranges ()
{
  test $# -gt 0 || set -- main
  readtab < "${1:?}.tab" | {
    typeset st et p extra sts ets curp lets
    while IFS=$'\t\n' read -r st et p extra
    do
      test "${st:0:1}" = "#" && continue
      test "${st:?}" != "-" -a "${et:?}" != "-" || {
        $LOG debug :ranges "Unknown range" "$st $et $extra"
        continue
      }
      test "${curp:-}" = "$p" || {
        unset lets
        curp=$p
      }
      echo "$st $et $p $extra"
      sts=$(time2seconds "$(stdtime "$st")")
      test -n "${lets:-}" && {
        echo last end to start: $(echo "scale=1; $sts - $lets"|bc) seconds
      }
      ets=$(time2seconds "$(stdtime "$et")")
      echo start to end: $(echo "scale=1; $ets - $sts"|bc) seconds
      lets=$ets
    done
  }
}


## User-script parts

pl_shortdescr='Media playlist utils'
pl_aliasargv ()
{
  case "$1" in
      ( "-?"|-h|h|help ) shift; set -- user_script_help "$@" ;;
  esac
}


# Main entry (see user-script.sh for boilerplate)

test -n "${user_script_loaded:-}" || {

  #shellcheck source=user-script.sh
  . "${US_BIN:="$HOME/bin"}"/user-script.sh &&
      user_script_shell_env

  #shellcheck source=pl.lib.sh
  . ${US_BIN:?}/pl.lib.sh
}

! script_isrunning "pl" .sh || {
  # Pre-parse arguments
  script_fun_xtra_defarg=pl_aliasargv
  script_xtra_defarg=aliasargv
  eval "set -- $(user_script_defarg "$@")"
}

script_entry "pl" "$@"
#
