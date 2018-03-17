#!/bin/sh
ht__source=$_

# Ht - trying to optimize htd.sh a bit

set -o posix
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
  lib_load vc
  vc_getscm && {
    vc_status || {
      error "VC getscm/status returned $?"
    }
    vc_diskuse

  } || { # not an checkout
    true
  }
} # End update-status

ht__update_all()
{
  true
} # End update-all


## Prefixes: named paths, or aliases for base paths

ht_man_1__prefixes='Manage local prefix table and index, or query cache.
'
ht__prefixes()
{
  test -n "$index" || local index=
  lib_load prefix
  test -s "$index" || req_prefix_names_index

  test -n "$1" || set -- op
  case "$1" in

    # Lookup with table
    name ) shift ;           htd_prefix "$1" || return $? ;;
    names ) shift ;          htd_prefixes "$@" || return $? ;;
    pairs ) shift ;          htd_path_prefixes "$@" || return $? ;;
    expand ) shift ;         htd_prefix_expand "$@" || return $? ;;

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


# Script main functions

ht_main()
{
  local scriptname=ht base=$(basename "$0" .sh) \
    scriptpath="$(cd "$(dirname "$0")"; pwd -P)" \
    upper= \
    package_id= package_cwd= package_env= \
    subcmd= subcmd_alias= subcmd_args_pre= \
    arguments= prefixes= options= \
    passed= skipped= error= failed=

  test -n "$verbosity" || verbosity=5

  ht_init || exit $?

  case "$base" in $scriptname | sd )

        ht_lib || exit $?

        # Fast boot for simple or direct cmd function suffix
        type ht__$1 1>/dev/null 2>&1 && {
            subcmd=$1
            shift 1
            ht__$subcmd "$@" || return $?
        } || {

            run_subcmd "$@" || exit $?
        }
      ;;

    * )
        error "not a frontend for $base ($scriptname)" 1
      ;;

  esac
}

ht_init()
{
  # NOTE: static init saves 100ms at 0.84s (12%)
  test -n "$ht_init_dyn" && {
      ht_init_dyn
  } || {
      ht_init_static
  }
  # -- ht box init sentinel --
}

ht_init_static()
{
  test -n "$scriptpath" || return
  export SCRIPTPATH=$scriptpath
  test -n "$LOG" -a -x "$LOG" || export LOG=$scriptpath/log.sh
  __load_mode=ext . $scriptpath/util.sh
  . $scriptpath/str.lib.sh
  . $scriptpath/sys.lib.sh
  . $scriptpath/os.lib.sh
  __load=ext . $scriptpath/std.lib.sh
  . $scriptpath/tools/sh/box.env.sh
  #box_run_sh_test
  str_lib_load
  sys_lib_load
  std_lib_load
  os_lib_load
  . $scriptpath/main.lib.sh
  # -- ht box init-static sentinel --
}

ht_init_dyn()
{
  test -n "$scriptpath" || return
  export SCRIPTPATH=$scriptpath
  test -n "$LOG" -a -x "$LOG" || export LOG=$scriptpath/log.sh
  __load_mode=ext . $scriptpath/util.sh
  lib_load
  . $scriptpath/tools/sh/box.env.sh
  box_run_sh_test
  # -- ht box init-dynamic sentinel --
}

ht_lib()
{
  test -z "$__load_lib" || return 14
  local __load_lib=1
  # -- ht box lib sentinel --
  set --
}

# Use hyphen to ignore source exec in login shell
case "$0" in "" ) ;; "-"* ) ;; * )
  # Ignore 'load-ext' sub-command
  test -n "$__load_lib" || {
    case "$1" in load-ext ) ;; * )
      ht_main "$@"
    ;; esac
  }
;; esac
