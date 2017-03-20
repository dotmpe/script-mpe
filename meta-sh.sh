#!/bin/sh
meta_sh__source=$_

# Using meta-sh (on Darwin)

set -e



version=0.0.3 # script-mpe


# Script subcmd's funcs and vars

# See $scriptname help to get started

# XXX mediainfo for OSX brew

meta_sh_man_1__info="Print meta_shdata (default command)"
meta_sh__info()
{
  test -n "$1" || error "Expected path" 1

  while test "$#" -gt 0
  do
      test -e "$1" || {
        error "Expected existing path" 1
      }
      mediainfo "$1"
      shift 1
  done
}


annex_md_update()
{
  test "$(git annex meta_shdata --get=$1 "$3")" = "$2" || {
    git annex meta_shdata --set $1=$2 "$3"
  }
}

meta_sh__video_info()
{
  test -e "$1" || {
    error "Expected existing path" 1
  }

  durms="$(mediadurationms "$1")"
  dar="$(mediadisplayaspectratio "$1")"
  ft="$(filetype "$1")"
  res="$(mediaresolution "$1")"
  test -n "$durms" || error "No duration <$1>" 1
  test -n "$res" || error "No resolution <$1>" 1
  test -n "$ft" || error "No file-type <$1>" 1
  test -n "$dar" || error "No display-aspectration <$1>" 1
  echo "mediatype=$ft"
  echo "durationms=$durms"
  echo "durationminutes=$(expr $durms / 1000 / 60 )"
  echo "display_aspectratio=$dar"
  echo "resolution=$res"
}

meta_sh__annex_update_video()
{
  test -n "$1" || error "Expected path" 1

  while test -n "$1"
  do
    meta_sh__video_info "$1"

    annex_md_update filetype $ft "$1"
    annex_md_update durationms $durms "$1"
    annex_md_update display_aspectratio $dar "$1"
    annex_md_update resolution $res "$1"

    shift 1
  done
}


# Generic subcmd's

meta_sh_man_1__help="Echo a combined usage and command list. With argument, seek all sections for that ID. "
meta_sh_spc__help='-h|help [ID]'
meta_sh__help()
{
  #std__help meta_sh "$@"
  base=meta_sh \
  choice_global=1 std__help "$@"
}
meta_sh_als___h=help


meta_sh_man_1__version="Version info"
meta_sh_spc__version="-V|version"
meta_sh__version()
{
  echo "script-mpe:$scriptname/$version"
}
meta_sh_als___V=version


meta_sh_man_1__edit_main="Edit the main script file"
meta_sh_spc__edit_main="-E|edit-main"
meta_sh__edit_main()
{
  locate_name $scriptname || exit "Cannot find $scriptname"
  note "Invoking $EDITOR $fn"
  $EDITOR $fn
}
meta_sh_als___E=edit-main


### Main


meta_sh__main()
{
  local scriptpath="$(cd "$(dirname "$0")"; pwd -P)"
  meta_sh_init || return 0

  local scriptname=meta-sh base=$(basename $0 .sh) verbosity=5

  case "$base" in $scriptname )

        local subcmd_def=info \
          subcmd_pref= subcmd_suf= \
          subcmd_func_pref=${base}__ subcmd_func_suf=

        meta_sh_lib

        # Execute
        run_subcmd "$@"
      ;;

  esac
}

# FIXME: Pre-bootstrap init
meta_sh_init()
{
  test -z "$BOX_INIT" || return 1
  test -n "$scriptpath"
  export SCRIPTPATH=$scriptpath
  . $scriptpath/util.sh load-ext
  lib_load
  . $scriptpath/box.init.sh
  box_run_sh_test
  lib_load main box meta
}

# FIXME: 2nd boostrap init
meta_sh_lib()
{
  # -- meta_sh box lib sentinel --
  set --
}


# Pre-exec: post subcmd-boostrap init
meta_sh_load()
{
  test -n "$UCONFDIR" || UCONFDIR=$HOME/.conf/
  test -n "$INO_CONF" || INO_CONF=$UCONFDIR/meta_sh
  test -n "$APP_DIR" || APP_DIR=/Applications

  hostname="$(hostname -s | tr 'A-Z.-' 'a-z__' | tr -s '_' '_' )"

  test -n "$EDITOR" || EDITOR=vim
  # -- meta_sh box load sentinel --
  set --
}

# Post-exec: subcmd and script deinit
meta_sh_unload()
{
  local unload_ret=0

  #for x in $(try_value "${subcmd}" "" run | sed 's/./&\ /g')
  #do case "$x" in
  # ....
  #    f )
  #        clean_failed || unload_ret=1
  #      ;;
  #esac; done

  clean_failed || unload_ret=$?

  env | grep -i 'meta'

  unset subcmd subcmd_pref \
          def_subcmd func_exists func \
          failed

  return $unload_ret
}



# Main entry - bootstrap script if requested
# Use hyphen to ignore source exec in login shell
case "$0" in "" ) ;; "-"* ) ;; * )

  # Ignore 'load-ext' sub-command
  # NOTE: arguments to source are working on Darwin 10.8.5, not Linux?
  # fix using another mechanism:
  test -z "$__load_lib" || set -- "load-ext"
  case "$1" in
    load-ext ) ;;
    * )
      meta_sh__main "$@" ;;

  esac ;;
esac

# Id: script-mpe/0.0.3 meta-sh.sh
