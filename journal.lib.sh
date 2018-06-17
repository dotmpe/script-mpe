#!/bin/sh


# Create symlinks for today and every weekdays in last, current and next week,
# The document contents are initialized with htd-rst-doc-create-update
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

  test -n "$*" ||
      set -- yesterday today tomorrow sunday monday tuesday wednesday thursday friday saturday

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

# the symlinks for the week, month, and years (also -1 to +1)
htd_jrnl_period_links()
{
  local jrnldir=$1 YSEP=$2
  shift 2
  test -n "$YSEP" || YSEP="/"
  test -n "$jrnldir" || jrnldir="$(pwd)/$JRNL_DIR"

  test -n "$EXT" || EXT=.rst
  local jr="$jrnldir$YSEP" \
      yfmt="$jrnldir$YSEP%G$D$EXT" \
      mfmt="$jrnldir$YSEP%G-%m$D$EXT" \
      wfmt="$jrnldir$YSEP%G-w%U$D$EXT"

  datelink "-7d" "${wfmt}" "${jr}last-week$EXT"
  datelink "" "${wfmt}" "${jr}week$EXT"
  datelink "+7d" "${wfmt}" "${jr}next-week$EXT"

  datelink "-1m" "${mfmt}" "${jr}last-month$EXT"
  datelink "" "${mfmt}" "${jr}month$EXT"
  datelink "+1m" "${mfmt}" "${jr}next-month$EXT"

  datelink "-1y" "${yfmt}" "${jr}last-year$EXT"
  datelink "" "${yfmt}" "${jr}year$EXT"
  datelink "+1y" "${yfmt}" "${jr}next-year$EXT"
}
