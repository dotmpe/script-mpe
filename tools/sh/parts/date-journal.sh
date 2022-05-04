#!/bin/sh

# Date journal period is either yearnr, monthnr, weeknr and always daynr
# corresponding to the day nr of the year for a day or the say at the start of a
# week/month/year period.
date_journal () # Year [ 'w'Week | Month [ Day ]]
{
  year=$1
  shift
  yearnr= monthnr= weeknr= enddate=
  case "$*" in

    [0-9][0-9]\ [0-9][0-9] ) date=$year-$1-$2 ;;

    w[0-9][0-9] )
        weeknr=$(echo "$1" | sed 's/^w0*//')
        date_week $weeknr $year
        date="$mon"
        enddate=$sun
        unset sun mon
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

# Derive: journal.lib.sh
