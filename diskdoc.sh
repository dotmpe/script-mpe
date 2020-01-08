#!/usr/bin/env bash
# /bin/sh
#((dirname "$0")dirname "$0") Created: 2016-02-22
diskdoc__source=$_

set -e -o posix



version=0.0.4-dev # script-mpe


# Script subcmd's funcs and vars

# See $scriptname help to get started

diskdoc_load__meta=y
diskdoc_man_1__meta='Defer to python script for YAML parsing'
diskdoc__meta()
{
  test -n "$1" || set -- --background

  fnmatch "$1" "-*" || {

    # Use socat as client, else performance is almost as bad as re-invoking
    # Python program each call.
    test -x $(which socat) -a -e "$sock" && {
      printf -- "$*\r\n" | socat -d - "UNIX-CONNECT:$sock" \
        2>&1 | tr "\r" " " | while read line
      do
        case "$line" in
          *" OK " )
            return
            ;;
          "? "* )
            return 1
            ;;
          "! "*": "* )
            return $(echo $line | sed 's/.*://g')
            ;;
        esac
        echo $line
      done
      return
    }
  }

  diskdoc.py -f $diskdoc --address $sock "$@" || return $?
}

# silent/quit
diskdoc__meta_sq()
{
  diskdoc__meta "$@" >/dev/null || return $?
}


diskdoc_load__status=ybf
diskdoc_man_1__help='Run over known prefixes and present status indicators'
diskdoc__status()
{
  test -z "$2" || error "Surplus arguments: $2" 1
  note "Getting status for checkouts $prefix"
  diskdoc.py disks | while read mount device type
  do
    note "TODO: check disk $mount"
    #vc_check $prefix || continue
    #test -d "$prefix" || continue
    #diskdoc__clean $prefix || touch $failed
  done
  rm_failed
}


diskdoc_load__check=ybf
diskdoc_man_1__check='Check with remote refs'
diskdoc__check()
{
  test -z "$2" || error "Surplus arguments: $2" 1
  note "Checking prefixes"
  diskdoc__meta list-disks "$1" | while read -r prefix
  do
    vc_check $prefix || continue
    test -d "$prefix" || continue
    diskdoc sync $prefix || touch $failed
  done
  rm_failed
}


#diskdoc_load__update=yfb
diskdoc__update()
{
  test -n "$1" || set -- "*"

  backup_if_comments "$diskdoc"
}



diskdoc_load__init=y
diskdoc__init()
{
  false
}


diskdoc_load__ids=y
diskdoc__ids()
{
  sudo blkid | while read -r devicer uuidr typer partuuidr
  do
    device=$(echo $devicer | cut -c-$(( ${#devicer} - 1 )))
    uuid=$(echo $uuidr | cut -c7-$(( ${#uuidr} - 8 )))
    type_=$(echo $typer | cut -c7-$(( ${#typer} - 1 )))
    partuuid=$(echo $partuuidr | cut -c11-$(( ${#partuuidr} - 1 )))

    grep -Fq $uuid $HOME/.conf/disk/mpe.yaml || {
      note "Unknown disk: $device $uuid "
    }
    grep -Fq $partuuid $HOME/.conf/disk/mpe.yaml || {
      note "Unknown partition: $device $type_ $partuuid "
    }
  done
}


# Generic subcmd's

diskdoc_man_1__help="Echo a combined usage and command list. With argument, seek all sections for that ID. "
diskdoc_load__help=f
diskdoc_spc__help='-h|help [ID]'
diskdoc__help()
{
  choice_global=1 std__help "$@"
  rm_failed || return
}
diskdoc_als___h=help


diskdoc_man_1__version="Version info"
diskdoc__version()
{
  echo "script-mpe/$version"
}
diskdoc_als__V=version


diskdoc__edit()
{
  $EDITOR $0 $(which diskdoc.py) "$@"
}



# Script main functions

diskdoc_main()
{
  local \
      scriptname=diskdoc \
      base=$(basename $0 .sh) \
      scriptpath="$(cd "$(dirname "$0")"; pwd -P)" \
      subcmd=$1

  case "$base" in

    $scriptname )

        # invoke with function name first argument,
        local scsep=__ bgd= \
          diskdoc_session_id= \
          subcmd_pref=${scriptname} \
          diskdoc_default=status \
          func_exists= \
          func= \
          main_bg=diskdoc__meta \
          main_sock= \
          c=0

		#export SCRIPTPATH=$scriptpath
        diskdoc_init "$@" || error "init failed" $?
        shift $c

        diskdoc_lib || error diskdoc-lib $?
        main_run_subcmd "$@" || error "run-subcmd:$*" $?

      ;;

    * )
      echo "$scriptname: not a frontend for $base"
      exit 1
      ;;

  esac
}

# FIXME: Pre-bootstrap init
diskdoc_init()
{
  local __load_lib=1
  #util_mode=ext . $sh_tools/util.sh || return
  #util_init

  . $scriptpath/tools/sh/init.sh

  . $scriptpath/tools/sh/box.env.sh
  lib_load box main src std
  box_run_sh_test
  #while test $# -gt 0
  #do
  #  case "$1" in
  #      -v )
  #        verbosity=$(( $verbosity + 1 ))
  #        incr_c
  #        shift;;
  #  esac
  #done
  # -- diskdoc box init sentinel --
}

# FIXME: 2nd boostrap init
diskdoc_lib()
{
  local __load_lib=1
  lib_load date match str-htd
  . $scriptpath/vc.sh load-ext
  # -- diskdoc box lib sentinel --
  set --
}


### Subcmd init, deinit

# Pre-exec: post subcmd-boostrap init
diskdoc_load()
{
  test -n "$diskdoc_session_id" || diskdoc_session_id=$(get_uuid)

  sys_lib_load
  str_lib_load

  for x in $(try_value "${subcmd}" "" load | sed 's/./&\ /g')
  do case "$x" in

      y )
        # set/check for Pd for subcmd

        diskdoc=projects.yaml

        # Find dir with metafile
        prerun=$(pwd)
        prefix=$2

        while test ! -e "$diskdoc"
        do
          test -n "$prefix" \
            && prefix="$(basename $(pwd))/$prefix" \
            || prefix="$(basename $(pwd))"
          cd ..
          test "$(pwd)" = "/" && break
        done

        test -e "$diskdoc" || error "No projects file $diskdoc" 1
        p="$(realpath $diskdoc | sed 's/[^A-Za-z0-9_-]/-/g' | tr -s '_' '-')"
        main_sock=/tmp/diskdoc-$p-serv.sock
        ;;

      f )
        # Preset name to subcmd failed file placeholder
        req_vars base subcmd
        # Preset name to subcmd failed file placeholder
        # include realpath of projectdoc (p)
        test -n "$pd" && {
          export failed=$(setup_tmpf .failed -$p-$subcmd-$diskdoc_session_id)
        } || failed=$(setup_tmpf .failed -$subcmd-$diskdoc_session_id )
        ;;

      b )
          # run metadata server in background for subcmd
          box_bg_setup
        ;;

    esac
  done

  export PD_SYNC_AGE=$_3HOUR

  local tdy="$(try_value "${subcmd}" "" today)"
  test -z "$tdy" || {
    today=$(statusdir.sh file $tdy)
    tdate=$(date +%y%m%d0000)
    test -n "$tdate" || error "formatting date" 1
    touch -t $tdate $today
  }

  uname=$(uname)
}

# Post-exec: subcmd and script deinit
diskdoc_unload()
{
  local unload_ret=0

  for x in $(try_value "${subcmd}" "" run | sed 's/./&\ /g')
  do case "$x" in
      y )
          test -z "$main_sock" || {
            box_bg_teardown
            unset bgd main_sock
          }
        ;;
      f )
          clean_failed || unload_ret=1
        ;;
  esac; done

  note "unload_ret=$unload_ret"

  unset subcmd subcmd_pref \
          diskdoc_default def_subcmd func_exists func \
          failed diskdoc_session_id

  return $unload_ret
}


# Main entry - bootstrap script if requested
case "$0" in "" ) ;; "-"* ) ;; * )

  # Ignore 'load-ext' sub-command
  # NOTE: arguments to source are working on Darwin 10.8.5, not Linux?
  # fix using another mechanism:
  test -z "$__load_lib" || set -- "load-ext"
  #case "$SHELL" in
  #    */bin/bash ) set -o nounset ;;
  #    */bin/dash ) set -o nounset -o pipefail ;;
  #esac
  test -z "${DEBUG-}" || set -x
  case "$1" in
    load-ext ) ;;
    * )
      diskdoc_main "$@" ;;

  esac ;;
esac

# Id: script-mpe/0.0.4-dev diskdoc.sh
