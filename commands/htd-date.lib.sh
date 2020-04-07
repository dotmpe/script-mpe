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
  test $# -ge 1 || set -- "iso"
  case "${1,,}" in

      help|-h|--help )
  echo "week number of year, with Sunday as first day of week (00..53)"
  date +%U
  echo "ISO week number with year (with Monday as first day of week) (01..53)"
  date +'%V.%g %V.%G'
  echo "week nr. as previously used"
  expr $(date +%U) + 1
          ;;

      "" )        date +%U ;;
      iso-w.y )   date +'%V.%g' ;;
      iso-w.Y )   date +'%V.%G' ;;
      iso )       date +%V ;;
  esac
}
