#!/bin/sh

# Per day/week/month/year paths/files


journal_lib_load()
{
  journal_weekdays="monday tuesday wednesday thursday friday saturday sunday"
  journal_weekdays_abbrev="mon tue wed thu fri sat sun"

  journal_days="yesterday today tomorrow $journal_weekdays"

  journal_monthnames="januari februari march april may june july august september october november december"
  journal_monthnames_abbrev="jan feb mar apr may jun jul aug sep oct nov dec"
  journal_months="$journal_monthnames $journal_monthnames_abbrev"
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

# Resolve numerical journal date spec. See also htd-jrnl-entry-spec.
journal_date () # YEAR [ 'w'WEEK | MONTH [DAY] ]
{
  year="$1"; shift; yearnr= monthnr= weeknr= enddate= p=
  case "$*" in

    [0-9][0-9]" "[0-9][0-9] ) date=$year-$1-$2 p=d ;;

    w[0-9][0-9] )
        weeknr=$(echo "$1" | sed 's/^w0*//')
        local sun sat
        date_week $weeknr $year
        date="$sun"
        enddate=$sat
        # XXX: year=$(date --date="$date" +'%G')
        p=w
      ;;

    [0-9][0-9] ) date=$year-$1-01
        monthnr=$(echo "$date" | cut -d'-' -f2)
        enddate=$year-$monthnr-$( cal $monthnr $year | awk 'NF {DAYS = $NF}; END {print DAYS}')
        p=m
      ;;

    "" ) date=$year-01-01
        yearnr="$year"
        enddate=$year-12-31
        p=y
      ;;

    * ) echo "No date parser for journal entry '$year $*'" >&2 ; return 2;;
  esac
  # week=$(date --date="$date" +'%V')  # ISO monday first 4-day week index
  # daynr=$(date --date="$date" +'%j')  # day of year nr
}


journal_title () # Entry | Date Period
{
  test $# -gt 0 || return 98
  local date p year yearnr monthnr weeknr enddate
  test -n "${1-}" && {
    journal_date "$1"
  } || {
    date="$2" p="$3"
  }
  case "$p" in

      y ) date_fmt "$date" "%Y" ;;

      m ) date_fmt "$date" "%B %G" ;;

      w ) local dayintoweek weekstart month_at_weekstart
          dayintoweek=$(date_fmt $date %u)
          weekstart="$(date_fmt "$date - ${dayintoweek}days" "%F" )"
          month_at_weekstart="$(date_fmt $weekstart %b)"
          date_fmt "$date" "Week %V, $month_at_weekstart %G"
        ;;

      d ) date_fmt "$date" "%A %G.%V" ;;

      * ) $LOG error "" "Unknown period" "$p" 1 ;;

  esac
}


# Create symlinks for today and every weekdays in last, current and next week.
journal_create_day_symlinks () # Journal-dir Fmt Ext
{
  local datep day ; for day in $journal_days; do case "$day" in

      yesterday ) datelink -1d "${jfmt}" ${jr}yesterday$3 >&2 ; echo "$datep" ;;
      today )     datelink "" "${jfmt}" ${jr}today$3 >&2 ; echo "$datep" ;;
      tomorrow )  datelink +1d "${jfmt}" ${jr}tomorrow$3 >&2 ; echo "$datep" ;;

      * )
          datelink "$day -7d" "${jfmt}" "${jr}last-$day$3" >&2 ; echo "$datep"
          datelink "$day +7d" "${jfmt}" "${jr}next-$day$3" >&2 ; echo "$datep"
          datelink "$day" "${jfmt}" "${jr}$day$3" >&2 ; echo "$datep"
      ;;

  esac; done
}

journal_create_period_symlinks () # Journal-Dir [Week-Fmt] [Month-Fmt] [Year-Fmt]
{
  local datep

  test -n "${2-}" && {
    datelink "-1w" "${2}" "${1}last-week$EXT" >&2 ; echo "$datep"
    datelink "" "${2}" "${1}week$EXT" >&2 ; echo "$datep"
    datelink "+1w" "${2}" "${1}next-week$EXT" >&2 ; echo "$datep"
  }

  test -n "${3-}" && {
    datelink "-1m" "${3}" "${1}last-month$EXT" >&2 ; echo "$datep"
    datelink "" "${3}" "${1}month$EXT" >&2 ; echo "$datep"
    datelink "+1m" "${3}" "${1}next-month$EXT" >&2 ; echo "$datep"
  }

  test -n "${4-}" && {
    datelink "-1y" "${4}" "${1}last-year$EXT" >&2 ; echo "$datep"
    datelink "" "${4}" "${1}year$EXT" >&2 ; echo "$datep"
    datelink "+1y" "${4}" "${1}next-year$EXT" >&2 ; echo "$datep"
  }
}

#
