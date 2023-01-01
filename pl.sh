
### Playlist util


ranges ()
{
  test $# -gt 0 || set -- main
  readtab "$@" < "${1:?}.tab" | {
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

# Read-tab wrapper to filter
filter () # ~ [<Tags <...>>]
{
  test $# -eq 0 || PL_TAGS=( "$@" )
  readtab "${PL_TAGS[@]:?}"
}

filtertab_if ()
{
  test -z "${PL_TAGS:-}" || {
    set -- ${PL_TAGS//:/ }
  }
  readtab "$@"
}

# Helper to
write () # ~ [<Tags <...>>]
{
  false
}

# Helper to (re)write output format if source tabfile (for basename) has changed.
update () # ~ <Basename>.<Ext> [ <Alt-tabfile> [ <Alt-output> ]]
{
  bn=${1:?}
  shift

  test ${bn:0:2} != ./ || bn=${bn:2}
  ext=${bn#*.}
  ext=${ext:-vlc.m3u}
  reader=$(printf '%s\n' ${ext//./ } | tac)
  reader=${reader//$'\n'/_}

  test $# -eq 0 && {
    test -e ${bn:?}.${ext:?} \
      -a ${bn:?}.${ext:?} -nt ${bn:?}.tab && {

      echo "File '${bn}.${ext}' is up to date with $bn.tab" >&2

    } || {
      echo "Writing '${bn}.${ext}' from $bn.tab (writepl_${reader//$'\n'/_})" >&2
      {
        filtertab_if < ${bn:?}.tab
      } | writepl_${reader} > ${bn:?}.${ext:?}
    }
  } || {
    # echo "Output as '${bn}.${ext}' from $bn.tab (writepl_${reader//$'\n'/_})" >&2
    {
      test "${1:-}" = "-" && {
        cat || $LOG error "" "" "E$?" $?
        exit $?
      } || {
        test -z "${1:-}" && {
          filtertab_if < ${bn:?}.tab || $LOG error "" "Reading tab" "E$?:$bn.tab" $?
          exit $?
        } || {
          filtertab_if < "${1}" || $LOG error "" "Reading tab" "E$?:$1" $?
          exit $?
        }
      }
    } | writepl_${reader} | {
      test "${2:-}" = "-" && {
        cat || $LOG error "" "" "E$?" $?
        exit $?
      } || {
        #test -z "${1:-}" && {
        cat >> "${2:?}"
      }
    }
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

pl_loadenv ()
{
  #shellcheck source=pl.lib.sh
  . ${US_BIN:?}/pl.lib.sh
}




# Main entry (see user-script.sh for boilerplate)

test -n "${user_script_loaded:-}" || {

  #shellcheck source=user-script.sh
  . "${US_BIN:="$HOME/bin"}"/user-script.sh &&
      user_script_shell_env
}

! script_isrunning "pl" .sh || {
  # Pre-parse arguments
  script_fun_xtra_defarg=pl_aliasargv
  script_xtra_defarg=aliasargv
  eval "set -- $(user_script_defarg "$@")"
}

script_entry "pl" "$@"
#
