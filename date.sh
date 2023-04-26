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

    ( ts-dt|timestamp-datetime ) shift;
        date -p @${1:?} ;;

    ( time-parse ) shift;
            time_parse_seconds "$1"
        ;;

    ( time-readable ) shift;
            echo "$1" | time_minsec_human_readable
        ;;

    ( time-readable-tag ) shift;
            time_minsec_human_readable_tag "$1"
        ;;

    ( relative ) shift;
        case "$2" in
            ( *"."* ) fmtdate_relative_f "$@" || return ;;
            ( * ) fmtdate_relative "$@" || return ;;
        esac;;

    ( relative-ts ) shift; case "$2" in
            ( *"."* ) fmtdate_relative_f "$@" || return ;;
            ( * ) fmtdate_relative "$@" || return ;;
        esac;;

    ( relative-ts-abbrev ) shift; { case "$2" in
            ( *"."* ) fmtdate_relative_f "$@" || return ;;
            ( * ) fmtdate_relative "$@" || return ;;
        esac
      } | time_fmt_abbrev || return;;

    #* ) echo "relative|relative-abbrev"; exit 1 ;;
    * ) exit 2 ;;

  esac

elif [ "$(basename -- "$0")" == "date.sh" ]
then
  date_load
  "$@"
fi
