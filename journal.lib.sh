#!/bin/sh


htd_jrnl_day_links()
{
  local jrnldir=$1 YSEP=$2 Y=%Y MSEP=$3 M=%m DSEP=$4 D=%d
  shift 1 ; shift 1 ; shift 1 ; shift 1 || true
  test -n "$YSEP" || YSEP="/"
  test -n "$MSEP" || MSEP="-"
  test -n "$DSEP" || DSEP="-"
  test -n "$jrnldir" || jrnldir="$(pwd)/$JRNL_DIR"
  jrnldir="$(strip_trail "$jrnldir")"
  test -d "$jrnldir" || error "Dir $1 must exist" 1

  # Append pattern to given dir path arguments
  test -n "$EXT" || EXT=.rst
  local jr="$jrnldir$YSEP" jfmt="$jrnldir$YSEP$Y$MSEP$M$DSEP$D$EXT"

  test -n "$*" || set -- yesterday today tomorrow sunday monday tuesday wednesday thursday friday saturday

  while test -n "$1"
  do
    case "$1" in

        yesterday)  datelink -1d "${jfmt}" ${jr}yesterday$EXT ;;
        today)      datelink "" "${jfmt}" ${jr}today$EXT ;;
        tomorrow )  datelink +1d "${jfmt}" ${jr}tomorrow$EXT ;;

        * )
            datelink "$1 -7d" "${jfmt}" "${jr}last-$1$EXT"
            datelink "$1 +7d" "${jfmt}" "${jr}next-$1$EXT"
            datelink "$1" "${jfmt}" "${jr}$1$EXT"
        ;;

    esac
    shift
  done
}
