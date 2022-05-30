#!/bin/bash

date_load ()
{
  set -e
  . "${US_BIN:-"$HOME/bin"}"/date-htd.lib.sh
  test -z "${DEBUG:-}" || set -x
}


if [ "$(basename -- "$0")" == "date-util" ]
then
  date_load

  case "${1-}" in

    ( relative ) shift; fmtdate_relative "$@" || return ;;
    ( relative-abbrev ) shift; {
        fmtdate_relative "$@" || return
      } | fmtdate_abbrev || return;;

    * | "" ) exit 64 ;;

  esac

elif [ "$(basename -- "$0")" == "date.sh" ]
then
  date_load
  "$@"
fi
