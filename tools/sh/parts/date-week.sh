#!/usr/bin/env bash


# Get first and last day of given week: sunday and saturday
date_week() # Week Year [Date-Fmt]
{
  test $# -ge 2 -a $# -le 3 || return 2
  test $# -eq 3 || set -- "$@" "+%Y-%m-%d"
  local week=$1 year=$2 date_fmt="$3"
  local week_num_of_Jan_1 week_day_of_Jan_1
  local first_Sun

  week_num_of_Jan_1=$(date -d $year-01-01 +%U)
  week_day_of_Jan_1=$(date -d $year-01-01 +%u)

  if ((week_num_of_Jan_1)); then
      first_Sun=$year-01-01
  else
      first_Sun=$year-01-$((01 + (7 - week_day_of_Jan_1) ))
  fi

  sun=$(date -d "$first_Sun +$((week - 1)) week" "$date_fmt")
  sat=$(date -d "$first_Sun +$((week - 1)) week + 6 day" "$date_fmt")
}

