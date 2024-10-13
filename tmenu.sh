#!/usr/bin/env bash

### A user menu system
# XXX: based on metadata and using shell (Bash) process control

: "${TMENU_PREFIX:=tmenu_}"
: "${TMENU_SEP:=:}"
: "${TMENU_FKVSEP:=__}"
: "${TMENU_DATAFILE:=user/menu.yml}"

tmenu_exists ()
{
  set -- "${1:?}${TMENU_SEP:?}1"
  local mvar=${TMENU_PREFIX:?}${1//${TMENU_SEP:?}/${TMENU_FKVSEP:?}}
  test -n "${!mvar:-}"
}

tmenu_new_popup () # ~ <Label> <9menu-argv...>
{
  exec ${nmenu:?} -popup -teleport \
      -fg "$tmenu_fg" -bg "$tmenu_bg" \
      -label "${@:?}"
}

main_menu () # ~ <Id>
{
  test $# -gt 0 || set -- home
  tmenu_sh=$(tmenu.py "${1:?}" < ${TMENU_DATAFILE}) || return
  eval "$tmenu_sh" || return

  test -n "${LAST-}" && {
    tmenu+=( "Back:$0 menu ${LAST:?}" )
  } || {
    tmenu+=( "Reload:$0 menu ${1:?}" )
    tmenu+=( "exit" )
  }
  : "$(printf " '%s'" "${tmenu[@]}")"
  stderr echo "LAST=${1:?} tmenu_new_popup '$label menu'$_"
  LAST=${1:?} tmenu_new_popup "$label menu" "${tmenu[@]}"
}

main_cmd ()
{
  eval "${*}"
  #pstree -p $M_PID
}

main_run ()
{
  echo "Main run: $*" >&2
  fnmatch "* -- *" " $* " && {
      main_seq "$@" || exit $?
  } || {
      main_cmd "$@"
  }
}

main_seq ()
{
  echo "Main seq: $*" >&2
  local cmdline=
  until test $# -eq 0 -o "${1:-}" == "--"
  do cmdline=$(printf '%s"%s"' "${cmdline:+$cmdline }" "$1")
    shift
  done
  echo "Eval cmd: $cmdline" >&2
  eval "$cmdline" || return
  test $# -eq 0 || shift
  test $# -eq 0 && return
  echo "main $*" >&2
  main_run "$@"
}

main ()
{
  set -meuo pipefail

  : "${USER_CONFIG_DIR:=$HOME/.config}"
  : "${USER_DATA_DIR:=$HOME/.local/share}"

  # Try ~/.config/tmenu/env.sh and ~/.conf/etc/tmenu/default.sh for config
  tmenu_conf=$USER_CONFIG_DIR/tmenu/env.sh
  test -e "$tmenu_conf" || tmenu_conf=${UCONF:?}/etc/tmenu/default.sh
  . "$tmenu_conf" || return

  # Using largest XFT is fairly satisfactory, however want some better frontend
  # on touch devices. Maybe using Weyland and some other menu app...?
  # xfont='-*-terminus-*-*-*-*-*-320-*-*-*-*-*-*'
  nmenu=9menu\ -font\ "$xfont"
  bg=bg.sh

  . "${US_BIN:=${HOME:?}/bin}/tool/sh/part/fnmatch.sh"

  main_act "$@"
}

main_act ()
{
  local main_act=${1:-menu}
  test $# -eq 0 || shift
  main_${main_act//-/_} "$@"
}

case "$(basename -- "$0" .sh)" in
    ( tmenu ) main "$@" ;;
esac
