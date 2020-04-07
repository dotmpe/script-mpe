#!/bin/sh

# Per day/week/month/year paths/files


journal_lib_load()
{
  journal_days="yesterday today tomorrow sunday monday tuesday wednesday thursday friday saturday"
}


# Output mtime, entry-id, path and base for each entry-path on stdin
journal_index()
{
  local path base bn entry mtime
  while read path
  do
    for base in $@
    do
      test -e "$base/$path" || continue
      bn="$(basename "$path" .rst)"
      case "$bn" in
        [0-9][0-9][0-9][0-9] | [0-9][0-9][0-9][0-9]-*[0-9][0-9]* )
            entry=$bn
          ;;
        * )
            entry=$(echo "$path" | cut -d'/' -f1-3 | tr ' ' '-' )
          ;;
      esac

      not_falseish "${journal_index_mtime-}" &&
        mtime="$(stat -c '%Y' "$base/$path")" || mtime="-"
      echo "$mtime $entry $path $base"
      break
    done
    test -e "$base/$path" || {
      echo "journal-index: Could not find base for $path in '$*'" >&2
      return 1
    }
  done
}


journal_entries()
{
  local entry base bn entry title date enddate year monthnr week weeknr daynr
  while read mtime entry path base
  do
    test -z "${DEBUG-}" || echo "journal-entries parsing $base/$path" >&2
    journal_date $(echo $entry | tr '/-' ' ')
    title="$(head -n 1 "$base/$path")"

    # Print Year day-of-year ISO-week date title
    test -n "$yearnr" -o -n "$monthnr" -o -n "$weeknr" && {
      test -n "$yearnr" && {
        # Number for day will be 365 or 366
        # Number for week will be either 52, 53 or 01
        echo "$year $(date --date="$enddate" +'%j') $(date --date="$enddate" +'%V') $entry $title"
      } || {
				echo "$year $daynr-$(date --date="$enddate" +'%j') $week-$(date --date="$enddate" +'%V') $entry $title"
      }
    } || {
      echo "$year $daynr $week $entry $title"
    }
  done
}


journal_date()
{
  year=$1
  shift
  yearnr= monthnr= weeknr= enddate=
  case "$*" in

    [0-9][0-9]\ [0-9][0-9] ) date=$year-$1-$2 ;;

    w[0-9][0-9] )
        weeknr=$(echo "$1" | sed 's/^w0*//')
        date_week $weeknr $year
        date="$sun"
        enddate=$sat
        unset sat sun
      ;;

    [0-9][0-9] ) date=$year-$1-01
        monthnr=$(echo "$date" | cut -d'-' -f2)
        enddate=$year-$monthnr-$( cal $monthnr $year | awk 'NF {DAYS = $NF}; END {print DAYS}')
      ;;

    "" ) date=$year-01-01
        yearnr="$year"
        enddate=$year-12-31
      ;;

    * ) echo "No date parser for journal entry '$year $*'" >&2 ; return 2;;
  esac
  year=$(date --date="$date" +'%Y')
  week=$(date --date="$date" +'%V')  # ISO monday first 4-day week index
  daynr=$(date --date="$date" +'%j')  # day of year nr
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
