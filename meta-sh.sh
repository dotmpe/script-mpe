#!/usr/bin/env make.sh
# Using meta-sh (on Darwin)

set -e



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

  durms="$(mediadurationms "$1")"
  dar="$(mediadisplayaspectratio "$1")"
  ft="$(file_mime "$1")"
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

    annex_md_update mimetype $ft "$1"
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
  (
    base=meta_sh \
      choice_global=1 std__help "$@"
  )
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


# Script main parts

main_env \
  INIT_ENV="init-log strict 0 0-src 0-u_s dev ucache scriptpath std box" \\
  INIT_LIB="\$default_lib main box meta std stdio logger-theme"

main_local \\
  subcmd_def=info subcmd_func_pref=${base}__

main_init \
  test -z "${BOX_INIT-}" || return 1 \
  test -n "$scriptpath" || return

main_load \
  test -n "${UCONF-}" || UCONF=$HOME/.conf/ \
  test -n "${INO_CONF-}" || INO_CONF=$UCONF/meta_sh \
  test -n "${APP_DIR-}" || APP_DIR=/Applications \
  hostname="$(hostname -s | tr 'A-Z.-' 'a-z__' | tr -s '_' '_' )" \
  test -n "${EDITOR-}" || EDITOR=vim

main-load-epilogue \
# Id: script-mpe/0.0.4-dev meta-sh.sh
