#!/bin/sh


htd_date_lib__init ()
{
  lib_load user-script || return
  lib_require shell-uc && shell_uc_lib__init || return
}


htd_date_touchdt()
{
  timestamp2touch "$@"
}

htd_date_touch()
{
  touch_ts "$@"
}

htd_date_opt_eargv ()
{
  local dt_opts=
  test $# -gt 0 && { dt_opts="-d $1"; shift; }
}

htd_date_nowopt_eargv ()
{
  test $# -gt 0 || set -- now
  eval "$(sh_type_fun_body htd_date_opt_eargv)"
}

htd_date_week() # ~ <Date> #
#
{
  local act=${1:-info} lk
  lk=:htd:date:week:$act
  test $# -eq 0 || shift

  $LOG info "$lk" "Starting..." "Argv:$*"
  case "$act" in

      info )
          # American calendars mostly use Sunday as start of the week [WP]
          $LOG info "$lk" \
      "week number, first Monday as first day of week 01 (American; 0..53)" \
              "%W:$(htd_date_week A "$@")"

          # In Christianity, Sunday is the seventh and Monday the first weekday.
          $LOG info "$lk" \
"week number of year, with Sunday as first day of week (Christian; 00..53)" \
              "%U:$(htd_date_week C "$@")"

          $LOG info "$lk" \
"ISO week number with year (ISO; with Monday as first day of week; 01..53)" \
              "%V:$(htd_date_week I "$@")"

          test $# -gt 0 || set -- now
          $LOG info "$lk" "week nr. as previously used was %U+1" \
              "$(expr $(date +%U -d "$@") + 1)"

          htd_date_week summary-all "$@"
        ;;

      A|american ) eval "$(sh_type_fun_body htd_date_nowopt_eargv)"
          date +%W $dt_opts ;;
      C|christian ) eval "$(sh_type_fun_body htd_date_nowopt_eargv)"
          date +%U $dt_opts ;;
      I|iso ) eval "$(sh_type_fun_body htd_date_nowopt_eargv)"
          date +%V $dt_opts ;;
      w|iso-w.y ) eval "$(sh_type_fun_body htd_date_nowopt_eargv)"
          date +"%V'%g" $dt_opts ;;
      W|iso-w.Y ) eval "$(sh_type_fun_body htd_date_nowopt_eargv)"
          date +'%V.%G' $dt_opts ;;

      S|summary-all ) eval "$(sh_type_fun_body htd_date_nowopt_eargv)"

          $LOG "notice" "$lk" "Old style notation" "%U+1"
          htd_date_week So "$@"
          $LOG "notice" "$lk" "New style notation" "ISO; w%V"
          htd_date_week Sn "$@"
          $LOG "notice" "$lk" "American style notation" "w%W"
          htd_date_week usa "$@"
          $LOG "notice" "$lk" "Christian style notation" "w%U"
          htd_date_week Sc "$@"
        ;;

      So|summary-old ) eval "$(sh_type_fun_body htd_date_nowopt_eargv)"
          lib_require date-htd || return

          htd_date_week_current

          week="$(expr $(date +%U $dt_opts) + 1)"
          echo "week $week'$year"
        ;;

      Sn|summary-new ) eval "$(sh_type_fun_body htd_date_nowopt_eargv)"
          lib_require date-htd || return

          # First week for year of given or current week
          htd_date_week_one
          echo "week 1'$year"
          htd_date_week range "$mon" "$sun"

          # Given week or current week
          htd_date_week_current
          echo "week $week'$year"
          htd_date_week range "$mon" "$sun"
        ;;

    range ) local mon=${1:?} sun=${2:?}
          echo $(date -d $mon +'%a w%V') -- $( date -d $sun +'%a w%V' )
        ;;


    * ) $LOG error "$lk" "No such action" "$act $*" 1
        return
        ;;

  esac
}

htd_date_week_one ()
{
  year=$(date +'%y' $dt_opts)
  Year=$(date +'%Y' $dt_opts)
  date_week 1 $Year
}

htd_date_week_current ()
{
  year=$(date +'%y' $dt_opts)
  Year=$(date +'%Y' $dt_opts)
  week=$(date +'%V' $dt_opts | sed 's/^0*//')
  date_week $week $Year
}

#
