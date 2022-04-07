#!/bin/sh


htd_date_touchdt()
{
  timestamp2touch "$@"
}

htd_date_touch()
{
  touch_ts "$@"
}

htd_date_week()
{
  test $# -ge 1 || set -- "info"
  case "${1,,}" in

      info ) local dt_opts=
        test $# -gt 1 && dt_opts="-d $2"

  echo "%U: week number of year, with Sunday as first day of week (00..53)"
  date +%U $dt_opts
  echo
  echo "%W: week number"
  date +%W $dt_opts
  echo
  echo "ISO week number with year (with Monday as first day of week) (01..53)"
  date +"%V'%g or %G.%V" $dt_opts
  echo
  echo "week nr. as previously used"
  expr $(date +%U $dt_opts) + 1

  lib_require date-htd || return

  year=$(date +'%Y' $dt_opts)
  echo
  echo "week 1'$year"
  date_week 1 $year
  echo mon=$mon sun=$sun
  echo $(date -d $mon +'%a %V') -- $( date -d $sun +'%a %V' )

  week=$(date +'%V' $dt_opts | sed 's/^0*//')
  echo
  echo "week $week'$year"
  date_week $week $year
  echo mon=$mon sun=$sun
  echo $(date -d $mon +'%a %V') -- $( date -d $sun +'%a %V' )

          ;;

      "" )        date +%U $dt_opts ;;
      iso-w.y )   date +'%V.%g' $dt_opts ;;
      iso-w.Y )   date +'%V.%G' $dt_opts ;;
      iso )       date +%V $dt_opts ;;
  esac
}
