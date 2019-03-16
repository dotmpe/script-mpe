#!/bin/sh

# Per day/week/month/year paths/files


journal_lib_load()
{
  journal_days="yesterday today tomorrow sunday monday tuesday wednesday thursday friday saturday"
}

jrnl_reqdir()
{
  test -n "$jrnldir" && {
    debug "Journal dir jrnldir using '$jrnldir'"
  } || {
    jrnldir="$(pwd)/$JRNL_DIR"
    std_info "Journal dir jrnldir set to PWD/JRNL-DIR: '$jrnldir'"
  }
  jrnldir="$(strip_trail "$jrnldir")"
  test -d "$jrnldir" || error "Dir $1 must exist" 1
}

# Create symlinks for today and every weekdays in last, current and next week,
# The document contents are initialized with htd-rst-doc-create-update
htd_jrnl_day_links()
{
  local jrnldir=$1 YSEP=$2 Y=%Y MSEP=$3 M=%m DSEP=$4 D=%d
  shift 1 ; shift 1 ; shift 1 ; shift 1 || true
  test -n "$YSEP" || YSEP="/"
  test -n "$MSEP" || MSEP="-"
  test -n "$DSEP" || DSEP="-"
  jrnl_reqdir

  # Append pattern to given dir path arguments
  test -n "$EXT" || EXT=.rst
  local jr="$jrnldir$YSEP" jfmt="$jrnldir$YSEP$Y$MSEP$M$DSEP$D$EXT"

  files_="$( htd_jrnl_create_day_symlinks "$jr" "$jfmt" )"
  test -n "$files" && export files="$files $files_" || export files="$files_"
}

htd_jrnl_create_day_symlinks()
{
  for day in $journal_days
  do
    case "$day" in

        yesterday)  datelink -1d "${jfmt}" ${jr}yesterday$EXT >&2 ; echo "$datep" ;;
        today)      datelink "" "${jfmt}" ${jr}today$EXT >&2 ; echo "$datep" ;;
        tomorrow )  datelink +1d "${jfmt}" ${jr}tomorrow$EXT >&2 ; echo "$datep" ;;

        * )
            datelink "$day -7d" "${jfmt}" "${jr}last-$day$EXT" >&2 ; echo "$datep"
            datelink "$day +7d" "${jfmt}" "${jr}next-$day$EXT" >&2 ; echo "$datep"
            datelink "$day" "${jfmt}" "${jr}$day$EXT" >&2 ; echo "$datep"
        ;;

    esac
  done
}

# the symlinks for the week, month, and years (also -1 to +1)
htd_jrnl_period_links()
{
  local jrnldir=$1 YSEP=$2
  shift 2
  test -n "$YSEP" || YSEP="/"
  jrnl_reqdir
  test -n "$EXT" || EXT=.rst
  local jr="$jrnldir$YSEP" \
      yfmt="$jrnldir$YSEP%G$D$EXT" \
      mfmt="$jrnldir$YSEP%G-%m$D$EXT" \
      wfmt="$jrnldir$YSEP%G-w%V$D$EXT"

  datelink "-1w" "${wfmt}" "${jr}last-week$EXT" >&2 ; echo "$datep"
  datelink "" "${wfmt}" "${jr}week$EXT" >&2 ; echo "$datep"
  datelink "+1w" "${wfmt}" "${jr}next-week$EXT" >&2 ; echo "$datep"

  datelink "-1m" "${mfmt}" "${jr}last-month$EXT" >&2 ; echo "$datep"
  datelink "" "${mfmt}" "${jr}month$EXT" >&2 ; echo "$datep"
  datelink "+1m" "${mfmt}" "${jr}next-month$EXT" >&2 ; echo "$datep"

  datelink "-1y" "${yfmt}" "${jr}last-year$EXT" >&2 ; echo "$datep"
  datelink "" "${yfmt}" "${jr}year$EXT" >&2 ; echo "$datep"
  datelink "+1y" "${yfmt}" "${jr}next-year$EXT" >&2 ; echo "$datep"
}
