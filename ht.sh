#!/bin/sh
# Created: 2018-03-17
ht__source=$_

# Ht - trying to optimize htd.sh a bit. See `HT:dev/main` docs.

#set -o posix
set -e

version=0.0.4-dev # script-mpe


## Local or global status

ht_man_1__status='Quick context status'
ht_als__st=status
ht_als__stat=status
ht__status()
{
  local key=htd:status:$hostname:$(ht__prefixes name $CWD)
  statusdir.sh exists $key || warn 1
  statusdir.sh members $key | while read status_key
  do
    note "$status_key"
  done
} # End status


ht_man_1__update_status='Update quick status'
ht_als__update=update-status
ht_als__update_stats=update-status
ht__update_status()
{
  local scm= scmdir= failed=$(setup_tmpf .failed)
  lib_load vc-htd
  vc_getscm && {
    vc_status || {
      error "VC getscm/status returned $?"
    }
    vc_diskuse

  } || { # not an checkout
    true
  }
} # End update-status


## Prefixes: named paths, or aliases for base paths

ht_man_1__prefixes='Manage local prefix table and index, or query cache.
'
ht__prefixes()
{
  test -n "$index" || local index=
  lib_load match prefix
  test -s "$index" || req_prefix_names_index

  test -n "$1" || set -- op
  case "$1" in

    # Lookup with table
    name ) shift ;           prefix_resolve "$1" || return $? ;;
    names ) shift ;          prefix_resolve_all "$@" || return $? ;;
    pairs ) shift ;          prefix_resolve_all_pairs "$@" || return $? ;;
    expand ) shift ;         prefix_expand "$@" || return $? ;;

    * ) error "No subcmd $1" ; return 1 ;;
  esac
  test ! -e "$index" || rm $index
} # End prefixes

ht_als__prefix=prefixes

ht_of__prefixes_list='plain text txt rst yaml yml json'
ht_als__prefixes_list=prefixes\ list
ht_als__list_prefixes=prefixes\ list

ht_of__prefixes_update='txt rst plain'
ht_als__prefixes_update=prefixes\ update
ht_als__update_prefixes=prefixes\ update


ht__filesize()
{
  filesize "$1"
}

ht_run__file=fl
ht__file()
{
  test -n "$1" || set -- info
  lib_load file
  subcmd_prefs=htd_file_\ file_ try_subcmd_prefixes "$@"
}
ht_als__test_name=file\ test-name
ht_als__file_info=file\ format
ht_als__file_modified=file\ mtime
ht_als__file_born=file\ btime
ht_als__file_mediatype=file\ mtype
ht_als__file_guessmime=file\ mtype
ht_als__drop=file\ drop
ht_als__filesize_hist=file\ size-histogram
ht_als__filenamext=file\ extensions
ht_als__filestripext=file\ stripext


ht_man_1__detect_ping='Test given host is online, answering to PING'
ht__detect_ping() # Host
{
  ping -qt 1 -c 1 $1 >/dev/null && stderr ok "$1" || return $?
}


ht__run()
{
  lib_load package
  test -e "$PACK_SCRIPTS/$1.sh" || return $?

  # Evaluate package env
  package_lib_set_local "$CWD" || error "Setting local package ($CWD)" 6
  . $PACKMETA_SH || error "local package" 7
  test "$package_type" = "application/vnd.org.wtwta.project" ||
                error "Project package expected (not $package_type)" 4

  (
    SCRIPTPATH=''
    unset Build_Deps_Default_Paths

    test -z "$package_cwd" || {
      note "Moving to '$package_cwd'"
      cd $package_cwd
    }
    . $CWD/$package_env_file &&
    . $CWD/$PACK_SCRIPTS/$1.sh
  )
  return $?
}


# Test command with OSX Automator
ht__xconsole()
{
  test -n "$1" || set -- test
  test -n "$ALT_EDITOR" || ALT_EDITOR=gvim
  case "$1" in

    -dialog )
        osascript -sso - "$2" <<EOF
on run argv
  display dialog "Hello, " & (item 1 of argv) & "."
end run
EOF
      ;;

    -query ) # NOTE: on my BSD this returns quoted output no-matter what,
        # so should eval str to sh var afterward.
        test -n "$2" || set -- "$1" Prompt
        osascript -sso <<EOF
on run
  set query to display dialog "$2:" default answer "" with icon note buttons {"Cancel", "Continue"} default button "Continue"
  if button returned of query is equal to "Cancel" then
    error number -128
  end if
  copy text returned of query to stdout
end run
EOF
      ;;

    -custom )
        eval cmd=$(ht__xconsole -query Command)
        eval "EDITOR=$ALT_EDITOR $cmd"
      ;;

    vt )
        cd ~/htdocs
        EDITOR=$ALT_EDITOR htd vt
      ;;

    doc )
        cd ~/htdocs
        htd doc exists && {
          EDITOR=$ALT_EDITOR htd doc edit || return $?
        } || {
          EDITOR=$ALT_EDITOR htd doc new
        }
      ;;

    doc-title )
        title_args_="$(ht__xconsole -query "Title/IDs")"
        title_args="$(echo "$title_args_" | cut -c2-$(( ${#title_args_} - 1)) )"

        cd ~/htdocs
        eval "EDITOR=$ALT_EDITOR htd doc exists $title_args" || {
            eval "EDITOR=$ALT_EDITOR htd doc new $title_args"
            return $?
        }
        eval "EDITOR=$ALT_EDITOR htd doc edit $title_args"
      ;;

    new-doc-title )
        cd ~/htdocs
        eval "EDITOR=$ALT_EDITOR htd doc new $(ht__xconsole -query "Title/IDs")"
      ;;

    new-doc )
        cd ~/htdocs
        EDITOR=$ALT_EDITOR htd doc new
      ;;

    status )
      ;;

    info )
      ;;

    help )
      ;;

  esac

  #open
}


ht_run__ssh=fl
ht__ssh()
{
  test -n "$1" || set -- info
  lib_load ssh
  subcmd_prefs=ssh_ try_subcmd_prefixes "$@"
}

# -- ht box insert sentinel --


# Script main functions

ht_main()
{
  local scriptname=ht base=$(basename "$0" .sh) \
    scriptpath="$(cd "$(dirname "$0")"; pwd -P)" \
    upper= \
    package_id= package_cwd= package_env= \
    subcmd= subcmd_alias= subcmd_args_pre= \
    arguments= subcmd_prefs= options= \
    passed= skipped= error= failed=

  test -n "$script_util" || script_util=$scriptpath/tools/sh
  test -n "$htd_log" || htd_log=$script_util/log.sh
  test -n "$verbosity" || verbosity=4

  ht_init || exit $?

  case "$base" in $scriptname | sd )

        ht_lib "$1" || exit $?

        # Fast boot for simple or direct cmd function suffix
        type ht__$1 1>/dev/null 2>&1 && {
            subcmd=$1
            shift 1
            ht__$subcmd "$@" || return $?
        } || {

            main_run_subcmd "$@" || exit $?
        }
      ;;

    * )
        error "not a frontend for $base ($scriptname)" 1
      ;;

  esac
}

# Initial step to prepare for subcommand
ht_init()
{
  test -n "$script_util" || return 103 # NOTE: sanity
  set -e

  # NOTE: static init saves 100ms at 0.84s (12%)
  test -n "$ht_init_dyn" && {
    ht_init_dyn || $LOG "error" "ERR:$?" "Ht dynamic init error" "" 1
  } || {
    ht_init_static
  }
  # -- ht box init sentinel --
}

ht_init_static()
{
  test -n "$script_util" || return 103 # NOTE: sanity
  test -n "$scriptpath" || return
  unset CWD
  # FIXME: instead going with hardcoded sequence for env-d like for lib.
  test -n "$htd_env_d_default" ||
      htd_env_d_default=init-log\ ucache\ scriptpath\ std
  #export SCRIPTPATH=$scriptpath
  test -n "$U_S" || export U_S=/srv/project-local/user-scripts
  test -n "$LOG" -a -x "$LOG" || export LOG=$scriptpath/tools/sh/log.sh
  #test -n "$LOG" -a -x "$LOG" || export LOG=$U_S/tools/sh/log.sh
  INIT_LOG=$LOG

  for env_d in $htd_env_d_default
  do
    . $script_util/parts/env-$env_d.sh
  done
  $htd_log "info" "" "Env initialized from parts" "$htd_env_d_default"

  util_mode=ext . $scriptpath/tools/sh/init-wrapper.sh || return
  #. $scriptpath/tools/sh/init.sh || return
  #scriptpath=$U_S/src/sh/lib . $U_S/tools/sh/init.sh || return

  lib_lib_load && lib_lib_init || return

  { __load=ext
    . $scriptpath/os-htd.lib.sh && os_htd_lib_loaded=0 && lib_loaded="$lib_loaded os_htd" &&
    . $scriptpath/sys-htd.lib.sh && sys_htd_lib_loaded=0 && lib_loaded="$lib_loaded sys_htd" &&
    . $scriptpath/std-ht.lib.sh && std_ht_lib_loaded=0 && lib_loaded="$lib_loaded std_ht" &&
    . $scriptpath/str-htd.lib.sh && str_htd_lib_loaded=0 && lib_loaded="$lib_loaded str_htd" &&
    . $scriptpath/main.lib.sh && main_lib_loaded=0 && lib_loaded="$lib_loaded main" &&
    . $U_S/src/sh/lib/os.lib.sh && os_lib_loaded=0 && lib_loaded="$lib_loaded os" &&
    . $U_S/src/sh/lib/sys.lib.sh && sys_lib_loaded=0 && lib_loaded="$lib_loaded sys" &&
    . $U_S/src/sh/lib/std.lib.sh && std_lib_loaded=0 && lib_loaded="$lib_loaded std" &&
    . $U_S/src/sh/lib/str.lib.sh && str_lib_loaded=0 && lib_loaded="$lib_loaded str" &&
    . $U_S/src/sh/lib/log.lib.sh && log_lib_loaded=0 && lib_loaded="$lib_loaded log" &&
    . $U_S/src/sh/lib/match.lib.sh && match_lib_loaded=0 && lib_loaded="$lib_loaded match" &&
    true
  } || $LOG "error" "ERR:$?" "Libs load" "" 1

  . $scriptpath/tools/sh/box.env.sh || return
  box_run_sh_test || return

  lib_init $lib_loaded || $LOG "error" "ERR:$?" "Libs init" "" 1
  unset INIT_LOG CWD
  # -- ht box init-static sentinel --
}

ht_init_dyn()
{
  test -n "$script_util" || return 103
  util_mode=boot . $script_util/init-wrapper.sh || return
  # -- ht box init-dynamic sentinel --
}

# Second step to prepare for subcommand
ht_lib()
{
  INIT_LOG=$LOG
  . $U_S/src/sh/lib/shell.lib.sh || return
  shell_lib_load && shell_lib_init || return
  unset INIT_LOG
  # -- ht box lib sentinel --
  set --
}

# Use hyphen to ignore source exec in login shell
case "$0" in "" ) ;; "-"* ) ;; * )

  # Ignore 'load-ext' sub-command
  test "$1" != load-ext || __load_lib=1
  test -n "${__load_lib-}" || {
    ht_main "$@"
  }
;; esac

# Id: script-mpe/0.0.4-dev ht.sh
