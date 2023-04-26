#!/usr/bin/env make.sh
# Using meta-sh (on Darwin)

set -eu

version=0.0.4-dev # script-mpe


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

  ft="$(filemtype "$1")"
  durms="$(mediainfo_durationms "$1")"
  dar="$(mediainfo_displayaspectratio "$1")"
  res="$(mediainfo_resolution "$1")"
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

  while test $# -gt 0
  do
    meta_sh__video_info "$1"

    annex_md_update mimetype $ft "$1"
    annex_md_update durationms $durms "$1"
    annex_md_update display_aspectratio $dar "$1"
    annex_md_update resolution $res "$1"

    shift 1
  done
}


# Generic subcmd's

meta_sh_als____version=version
meta_sh_als___V=version
meta_sh_grp__version=ctx-main\ ctx-std

meta_sh_als____help=help
meta_sh_als___h=help
meta_sh_grp__help=ctx-main\ ctx-std


meta_sh_man_1__edit_main="Edit the main script file"
meta_sh_spc__edit_main="-E|edit-main"
meta_sh__edit_main()
{
  locate_name $scriptname || exit "Cannot find $scriptname"
  note "Invoking $EDITOR $fn"
  $EDITOR $fn
}
meta_sh_als___E=edit-main


# Script main parts

main-init-env \
  INIT_ENV="init-log strict 0 0-src 0-u_s dev ucache scriptpath std box" \\
INIT_LIB="\$default_lib main box meta std stdio logger-theme ctx-std"

main-default info

main-init \
  test -z "${BOX_INIT-}" || return 1 \
  test -n "$scriptpath" || return

main-load \
  test -n "${UCONF-}" || UCONF=$HOME/.conf/ \
  test -n "${INO_CONF-}" || INO_CONF=$UCONF/meta_sh \
  test -n "${APP_DIR-}" || APP_DIR=/Applications \
  hostname="$(hostname -s | tr 'A-Z.-' 'a-z__' | tr -s '_' '_' )" \
  test -n "${EDITOR-}" || EDITOR=vim

main-load-epilogue \
# Id: script-mpe/0.0.4-dev meta-sh.sh
