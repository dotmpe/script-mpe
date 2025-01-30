#!/usr/bin/env bash

[[ ${SCRIPTNAME+set} ]] || {
  : "${0##*/}"; : "${_%.sh}"; SCRIPTNAME=$_;

  case "${SCRIPTNAME?}" in
  ( "symlink-util" )
    set -euETo pipefail

    case "${1-}" in
    ( realtarget-cb ) # ~ <Symlink-path> <Command ...>
        "${@:3}" "$(realpath "$(readlink "${2:?}")")"
      ;;

    ( sources ) # ~ ~ <Basedir> [<Dest-base...>]
        . ~/.l/c/System/OS/sources.inc &&
        group () { :; } &&
        os-sources "${@:2}"
      ;;

    ( target-cb ) # ~ <Symlink-path> <Command ...>
        "${@:3}" "$(readlink "${2:?}")"
      ;;

    ( * ) exit ${_E_nsk:-67}
    esac
  ;;

  ( "file-util" )
    false
  ;;

  ( * ) exit ${_E_nsc:-64}
  esac
}
