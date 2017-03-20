#!/bin/sh
# Created: 2016-04-09
box_instance__source="$_"

set -e



version=0.0.3 # script-mpe


# Script subcmd's funcs and vars

box_instance_man_1__x=abc
box_instance_load__x=f
box_instance_spc__x="x ARG [ARG..]"
box_instance__x()
{
  test -n "$1" && {
    note "Running X"
  } || {
    error "Arguments expected"
    touch $failed
  }
}

box_instance_load__y=f
box_instance__y()
{
  test -z "$1" && {
    note "Running Y"
  } || {
    error "No arguments eypected"
    echo 1 > $failed
  }
}


# Generic subcmd's

box_instance_man_1__help="Echo a combined usage and command list. With argument, seek all sections for that ID. "
box_instance_load__help=f
box_instance_spc__help='-h|help [ID]'
box_instance__help()
{
  choice_global=1 std__help "$@"
  rm_failed || return
}
box_instance_als___h=help


box_instance_man_1__version="Version info"
box_instance__version()
{
  echo "script-mpe/$version"
}
box_instance_als__V=version


box_instance__edit()
{
  $EDITOR $0 $(which box_instance.py) "$@"
}



# Script main functions

box_instance_main()
{
  local \
      scriptname=box-instance \
      base="$(basename $0 ".sh")" \
      scriptpath="$(cd $(dirname $0); pwd -P)" \
      failed=
  case "$base" in
    $scriptname )
      box_instance_init || return $?
      run_subcmd "$@" || return $?
      ;;
    * )
      echo "$scriptname: not a frontend for $base"
      exit 1
      ;;
  esac
}

# FIXME: Pre-bootstrap init
box_instance_init()
{
  export LOG=/srv/project-local/mkdoc/usr/share/mkdoc/Core/log.sh

  . $scriptpath/main.lib.sh load-ext
  . $scriptpath/std.lib.sh
  . $scriptpath/str.lib.sh
  . $scriptpath/util.sh
  . $scriptpath/box.init.sh
  box_run_sh_test
  # -- box_instance box init sentinel --
}

# Pre-exec: post subcmd-boostrap init
box_instance_load()
{
  local __load_lib=1
  . $scriptpath/match.sh load-ext
  # -- box_instance box load sentinel --

  for x in $(try_value "${subcmd}" load | sed 's/./&\ /g')
  do case "$x" in

      f )
        debug "Preparing failed report for subcmd $subcmd"
        # Preset name to subcmd failed file placeholder
        req_vars base subcmd
        test -n "$box_instance" && {
          req_vars p
          failed=/tmp/${base}-$p-$subcmd.failed
        } || {
          failed=/tmp/${base}-$subcmd.failed
        }
      ;;

    esac
  done

  PWD=$(pwd -P)
  #PATH=$PWD:$PATH

  hostname=$(hostname -s)
  uname=$(uname)

  str_load
}

box_instance_unload()
{
  test -z "$failed" -o ! -e "$failed" || {
    test -s "$failed" && {
      count="$(sort -u $failed | wc -l | awk '{print $1}')"
      test "$count" -gt 2 && {
        warn "Failed: $(echo $(sort -u $failed | head -n 3 )) and $(( $count - 3 )) more"
        rotate-file $failed .failed
      } || {
        warn "Failed: $(echo $(sort -u $failed))"
      }
    }
    test ! -e "$failed" || rm $failed
    unset failed
    return 1
  }
}


# Main entry - bootstrap script if requested
case "$0" in "" ) ;; "-"* ) ;; * )
  # XXX: cleanup test -z "$__load_lib" || set -- "load-ext"
  case "$1" in load-ext ) ;; * )
      box_instance_main "$@" || exit $? ;;
  esac ;;
esac

