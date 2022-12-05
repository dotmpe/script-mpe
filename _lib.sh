#

sh_mode ()
{
  test $# -eq 0 && {
    # XXX: sh-mode summary
    echo "$0: sh-mode: $-" >&2
    trap >&2
  } || {
    while test $# -gt 0
    do
      case "${1:?}" in

          ( dev )
                sh_mode_exc $opt log-error "$@"
                set -hET &&
                shopt -s extdebug &&
                . "${U_C}"/script/bash-uc.lib.sh &&
                trap 'bash_uc_errexit' ERR || return
              ;;

          ( log-error )
                sh_mode_exc $opt dev "$@"
                set -CET &&
                trap "LOG_error_handler" ERR || return
              ;;

          ( mod )
                  sh_mode strict log-error &&
                  shopt -s expand_aliases
              ;;

          ( strict )
                  set -euo pipefail
              ;;

      esac
      shift
    done
  }
}
# Copy: sh-mode

LOG_error_handler ()
{
  local r=$? lastarg=$_
  $LOG error ":on-error" "In command '${0}' ($lastarg)" "E$r"
  exit $r
}
# Copy: LOG-error-handler

#
