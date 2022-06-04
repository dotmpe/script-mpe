#!/usr/bin/env bash

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

    ( relative ) shift; case "$2" in
            ( *"."* ) fmtdate_relative_f "$@" || return ;;
            ( * ) fmtdate_relative "$@" || return ;;
        esac;;

    ( relative-abbrev ) shift; { case "$2" in
            ( *"."* ) fmtdate_relative_f "$@" || return ;;
            ( * ) fmtdate_relative "$@" || return ;;
        esac
      } | fmtdate_abbrev || return;;

    * ) echo "relative|relative-abbrev"; exit 1 ;;
    * ) exit 2 ;;

  esac

elif [ "$(basename -- "$0")" == "date.sh" ]
then
  date_load
  "$@"
fi
