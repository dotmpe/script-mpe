#!/usr/bin/env bash

# Get first and last day of given week: monday and sunday (ISO)
date_week() # Week Year [Date-Fmt]
{
  test $# -ge 2 -a $# -le 3 || return 2
  test $# -eq 3 || set -- "$@" "+%Y-%m-%d"
  local week=$1 year=$2 date_fmt="$3"
  local week_num_of_Jan_4 week_day_of_Jan_4
  local first_Mon

  # decimal number, range 01 to 53
  week_num_of_Jan_4=$(date -d $year-01-04 +%V | sed 's/^0*//')
  # range 1 to 7, Monday being 1
  week_day_of_Jan_4=$(date -d $year-01-04 +%u)

  # now get the Monday for week 01
  if test $week_day_of_Jan_4 -le 4
  then
    first_Mon=$year-01-$((1 + 4 - week_day_of_Jan_4))
  else
    first_Mon=$((year - 1))-12-$((1 + 31 + 4 - week_day_of_Jan_4))
  fi

  mon=$(date -d "$first_Mon +$((week - 1)) week" "$date_fmt")
  sun=$(date -d "$first_Mon +$((week - 1)) week + 6 day" "$date_fmt")
}

# Derive: date-htd.lib.sh
