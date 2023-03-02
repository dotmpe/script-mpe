#!/usr/bin/env bash

### A user menu system
# XXX: based on metadata and using shell (Bash) process control

true "${TMENU_PREFIX:=tmenu_}"
true "${TMENU_SEP:=:}"
true "${TMENU_FKVSEP:=__}"

tmenu_exists ()
{
  set -- "${1:?}${TMENU_SEP:?}1"
  local mvar=${TMENU_PREFIX:?}${1//${TMENU_SEP:?}/${TMENU_FKVSEP:?}}
  test -n "${!mvar:-}"
}

tmenu_new_popup ()
{
  exec ${_9menu:?} -popup -label "${@:?}"
}

main_menu ()
{
  test $# -gt 0 || set -- home
  tmenu_sh=$(tmenu.py "${1:?}" < user.menu.yml) || return
  eval "$tmenu_sh" || return
  test -n "${LAST:-}" && {
    tmenu+=( "Back:$0 menu ${LAST:?}" )
  } || {
    tmenu+=( "Reload:$0 menu root" )
    tmenu+=( "exit" )
  }
  LAST=${1:?} tmenu_new_popup "$label menu" -warp "${tmenu[@]}"
}

main_cmd ()
{
  eval "${*}"
  #pstree -p $M_PID
}

main_run ()
{
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

  true "${USER_CONFIG_DIR:=$HOME/.config}"
  true "${USER_DATA_DIR:=$HOME/.local/share}"

  tmenu_conf=$USER_CONFIG_DIR/tmenu/env.sh
  test -e "$tmenu_conf" || tmenu_conf=${UCONF:?}/etc/tmenu/default.sh
  . "$tmenu_conf" || return

  _9menu=9menu\ -font\ "$xfont"
  bg=bg.sh

  . "${US_BIN:=${HOME:?}/bin}/tools/sh/parts/fnmatch.sh"

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
