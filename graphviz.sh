#!/bin/sh
# Created: 2015-12-14


### Sub-commands


gv__edit()
{
  $EDITOR \
    $0 \
    ~/bin/graphviz.inc.sh \
    $(which graphviz.py) \
    "$@"
}

gv_run__meta=G
# Defer to python
gv__meta()
{
  test -n "$1" || set -- "--background"
  graphviz.py --file $graph --address $sock "$@" || return $?
}

gv_run__bg=G
# Defer and wait
gv__bg()
{
  note "Starting Bg service"
  gv__meta "$@" &
  sock="$(gv__meta print-socket-name)"

  while test ! -e "$sock"
  do note "Waiting for Bg at $sock"; sleep 2;
  done

  info "Backgrounded"
}

gv_run__info=G #b
# Test argv
gv__info()
{
  gv__meta print-info
}


# ----


gv__usage()
{
  echo 'Usage: '
  echo "  $scriptname.sh <cmd> [<args>..]"
}

gv__help()
{
  gv__usage
  echo 'Functions: '
  echo ''
  echo '  help                             print this help listing.'
  std__help gv "$@"
}


# Pre-run: Initialize from argv/env to run subcmd
gv_init()
{
  local parse_all_argv= \
    scsep=__ \
    subcmd_pref=${scriptalias} \
    def_subcmd=status

  gv_preload || {
    error "preload" $?
  }

  gv_parse_argv "$@" || {
    error "parse-argv" $?
  }

  shift $c

  test -n "$subcmd_func" || {
    error "func required" $?
  }

  gv__lib "$@" || {
    error "lib error '$@'" $?
  }

  local tdy="$(try_value "${subcmd}" "" today)"

  test -z "$tdy" || {
    today=$(statusdir.sh file $tdy)
    tdate=$(date +%y%m%d0000)
    test -n "$tdate" || error "formatting date" 1
    touch -t $tdate $today
  }

  uname=$(uname)

  box_src_lib gv
}

# Init stage 1: Preload libraries
gv_preload()
{
  local __load_lib=1
  test -n "$scriptdir"
  test -n "$BIN" || BIN=$scriptdir
  . $scriptdir/main.sh
  . $scriptdir/graphviz.inc.sh "$@"
  . $scriptdir/date.lib.sh
  . $BIN/match.sh load-ext
  . $BIN/vc.sh load-ext
  test -n "$verbosity" || verbosity=6
  # -- gv box init sentinel --
}

# Pre-run stage 3: more libraries, possibly for subcmd.
gv__lib()
{
  local __load_lib=1
  . $BIN/box.lib.sh
  # -- gv box lib sentinel --
}


### Main

gv_main()
{
  test -z "$__load_lib" || return 1

  local scriptname=graphviz scriptalias=gv base=$(basename $0 .sh) \
    subcmd=$1 \
    scriptdir="$(cd "$(dirname "$0")"; pwd -P)"


  case "$base" in

    $scriptname | $scriptalias )

        # invoke with function name first argument,
        local subcmd_func= c=0

  			export SCRIPTPATH=$scriptdir
				. $scriptdir/util.sh

        gv_init "$@" || {
          error "init error '$@'" 1
        }

        shift $c

        $subcmd_func "$@" || r=$?
          #XXX: choice_quiet?
          #gv_unload || error "unload on error failed: $?"
          #error "exec error $subcmd_func: $r" $r

        gv_unload || {
          error "unload error"
        }

        exit $r

      ;;

    * )
      echo "Not a frontend for $base ($scriptname)"
      exit 1
      ;;

  esac
}

case "$0" in "" ) ;; "-"* ) ;; * )

  # Ignore 'load-ext' sub-command
  # XXX arguments to source are working on Darwin 10.8.5, not Linux?
  # fix using another mechanism:
  test -z "$__load_lib" || set -- "load-ext"
  case "$1" in load-ext ) ;; * )

      gv_main "$@"
    ;;

  esac ;;
esac


