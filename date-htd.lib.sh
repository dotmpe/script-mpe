#!/bin/sh

# TODO /etc/localtime

date_htd_lib_load()
{
  export TODAY=+%y%m%d0000

  # Age in seconds
  export _1MIN=60
  export _2MIN=120
  export _3MIN=180
  export _4MIN=240
  export _5MIN=300
  export _10MIN=600
  export _15MIN=900
  export _20MIN=1200
  export _30MIN=1800
  export _45MIN=2700

  export _1HOUR=3600
  export _3HOUR=10800
  export _6HOUR=64800

  export _1DAY=86400
  export _1WEEK=604800

  # Note: what are the proper lengths for month and year? It does not matter that
  # much if below is only used for fmtdate-relative.
  export _1MONTH=$(( 31 * $_1DAY ))
  export _1YEAR=$(( 365 * $_1DAY ))
}


date_lib_init()
{
  test "${date_lib_init-}" = "0" && return

  lib_assert sys os str || return
  case "$uname" in
    Darwin ) gdate="gdate" ;;
    Linux ) gdate="date" ;;
    * ) $INIT_LOG "error" "" "uname" "$uname" 1 ;;
  esac

  TZ_OFF_1=$($gdate -d '1 Jan' +%z)
  TZ_OFF_7=$($gdate -d '1 Jul' +%z)
  TZ_OFF_NOW=$($gdate +%z)

  test \( $TZ_OFF_NOW -gt $TZ_OFF_1 -a $TZ_OFF_NOW -gt $TZ_OFF_7 \) &&
    IS_DST=1 || IS_DST=0

  export gdate
}


# newer-than FILE SECONDS, filemtime must be greater-than Now - SECONDS
newer_than() # FILE SECONDS
{
  test -n "${1-}" || error "newer-than expected path" 1
  test -e "$1" || error "newer-than expected existing path" 1
  test -n "${2-}" || error "newer-than expected delta seconds argument" 1
  test -z "${3-}" || error "newer-than surplus arguments" 1
  #us_fail $_E_GAE --\
  #  std_argv eq 2 $# "Newer-than argc expected" --\
  #  assert_ n "${1-}" "Newer-than expected path" --\
  #  assert_ e "${1-}" "Newer-than expected existing path" --\
  #  assert_ n "${2-}" "Newer-than expected delta seconds argument" || return

  fnmatch "@*" "$2" || set -- "$1" "-$2"
  test $(date_epochsec "$2") -lt $(filemtime "$1")
}

newer_than_all () # (REFFILE|@TIMESTAMP) PATHS...
{
  local ref path fm
  fnmatch "@*" "$1" && ref="${1:1}" || { ref=$(filemtime "$1") || return; }
  shift
  for path in $@
  do
    #test -e "$path" || continue
    fm=$(filemtime "$path"); test ${fm:-0} -lt $ref
  done
}

# older-than FILE SECONDS, filemtime must be less-than Now - SECONDS
older_than ()
{
  test -n "${1-}" || error "older-than expected path" 1
  test -e "$1" || error "older-than expected existing path" 1
  test -n "${2-}" || error "older-than expected delta seconds argument" 1
  test -z "${3-}" || error "older-than surplus arguments" 1
  #us_fail $_E_GAE --\
  #  std_argv eq 2 $# "Older-than argc expected" --\
  #  assert_ n "${1-}" "Older-than expected path" --\
  #  assert_ e "${1-}" "Older-than expected existing path" --\
  #  assert_ n "${2-}" "Older-than expected delta seconds argument" || return

  fnmatch "@*" "$2" || set -- "$1" "-$2"
  test $(date_epochsec "$2") -gt $(filemtime "$1")
  #test $(( $(date +%s) - $2 )) -gt $(filemtime "$1")
}

date_ts()
{
  date +%s
}

date_epochsec () # File | -Delta-Seconds | @Timestamp | Time-Fmt
{
  test $# -eq 1 || return 64
  test -e "$1" && {
      filemtime "$1"
      return $?
    } || {

      fnmatch "-*" "$1" && {
        echo "$(date_ts) $1" | bc
        return $?
      }

      fnmatch "@*" "$1" && {
        echo "$1" | cut -c2-
        return $?
      } || {
        date_fmt "$1" "%s"
        return $?
      }
    }
  return 1
}

# See +U-c
# date_fmt() # Date-Ref Str-Time-Fmt


# Compare date, timestamp or mtime and return oldest as epochsec (ie. lowest val)
date_oldest() # ( FILE | DTSTR | @TS ) ( FILE | DTSTR | @TS )
{
  set -- "$(date_epochsec "$1")" "$(date_epochsec "$2")"
  test $1 -gt $2 && echo $2
  test $1 -lt $2 && echo $1
}

# Compare date, timestamp or mtime and return newest as epochsec (ie. highest val)
date_newest() # ( FILE | DTSTR | @TS ) ( FILE | DTSTR | @TS )
{
  set -- "$(date_epochsec "$1")" "$(date_epochsec "$2")"
  test $1 -lt $2 && echo $2
  test $1 -gt $2 && echo $1
}

# given timestamp, display a friendly human readable time-delta:
# X sec/min/hr/days/weeks/months/years ago
fmtdate_relative() # [ Previous-Timestamp | ""] [Delta] [suffix=" ago"]
{
  # Calculate delta based on now
  test -n "${2-}" || set -- "${1-}" "$(( $(date +%s) - $1 ))" "${3-}"

  # Set default suffix
  test -n "${3-}" -o -z "${datefmt_suffix-}" || set -- "${1-}" "$2" "$datefmt_suffix"

  test -n "${3-}" || set -- "${1-}" "$2" " ago"

  if test $2 -gt $_1YEAR
  then

    if test $2 -lt $(( $_1YEAR + $_1YEAR ))
    then
      printf -- "one year$3"
    else
      printf -- "$(( $2 / $_1YEAR )) years$3"
    fi
  else

    if test $2 -gt $_1MONTH
    then

      if test $2 -lt $(( $_1MONTH + $_1MONTH ))
      then
        printf -- "a month$3"
      else
        printf -- "$(( $2 / $_1MONTH )) months$3"
      fi
    else

      if test $2 -gt $_1WEEK
      then

        if test $2 -lt $(( $_1WEEK + $_1WEEK ))
        then
          printf -- "a week$3"
        else
          printf -- "$(( $2 / $_1WEEK )) weeks$3"
        fi
      else

        if test $2 -gt $_1DAY
        then

          if test $2 -lt $(( $_1DAY + $_1DAY ))
          then
            printf -- "a day$3"
          else
            printf -- "$(( $2 / $_1DAY )) days$3"
          fi
        else

          if test $2 -gt $_1HOUR
          then

            if test $2 -lt $(( $_1HOUR + $_1HOUR ))
            then
              printf -- "an hour$3"
            else
              printf -- "$(( $2 / $_1HOUR )) hours$3"
            fi
          else

            if test $2 -gt $_1MIN
            then

              if test $2 -lt $(( $_1MIN + $_1MIN ))
              then
                printf -- "a minute$3"
              else
                printf -- "$(( $2 / $_1MIN )) minutes$3"
              fi
            else

              printf -- "$2 seconds$3"

            fi
          fi
        fi
      fi
    fi
  fi
}

# Output date at required resolution
date_autores() # Date-Time-Str
{
  fnmatch "@*" "$1" && {
    true ${dateres:="minutes"}
    set -- "$(date_iso "${1:1}" minutes)"
  }
  echo "$1" | sed \
      -e 's/T00:00:00//' \
      -e 's/T00:00//' \
      -e 's/:00$//'
}

# Tag: seconds, minutes, hours, days, years
ts_rel() # Seconds-Delta [Tag]
{
  test -n "$2" || set -- "$1" hours
  case "$2" in
      seconds ) dt=$1 ; dt_rest=0;;
      minutes ) dt=$(( $1 / $_1MIN ))  ; dt_rest=$(( $1 % $_1MIN ));;
      hours )   dt=$(( $1 / $_1HOUR )) ; dt_rest=$(( $1 % $_1HOUR ));;
      days )    dt=$(( $1 / $_1DAY ))  ; dt_rest=$(( $1 % $_1DAY ));;
      weeks )   dt=$(( $1 / $_1WEEK )) ; dt_rest=$(( $1 % $_1WEEK ));;
      years )   dt=$(( $1 / $_1YEAR )) ; dt_rest=$(( $1 % $_1YEAR ));;
  esac
}

ts_rel_multi() # Seconds-Delta [Tag [Tag...]]
{
  local dt= dt_maj= dt_rest= dt_min=
  ts_rel "$@" ; dt_maj="$dt" ; shift 2
  while test $# -gt 0
  do
      ts_rel "$dt_rest" "$1" ; shift
      test ${#dt} -gt 1 || dt=0$dt
      dt_min="$dt_min:$dt"
  done
  dt_rel="$dt_maj$dt_min"
}

# Get stat datetime format, given file or datetime-string. Prepend @ for timestamps.
timestamp2touch() # [ FILE | DTSTR ]
{
  test -n "$1" || set -- "@$(date_ts)"
  test -e "$1" && {
    $gdate -r "$1" +"%y%m%d%H%M.%S"
  } || {
    $gdate -d "$1" +"%y%m%d%H%M.%S"
  }
}

# Copy mtime from file or set to DATESTR or @TIMESTAMP
touch_ts() # ( DATESTR | TIMESTAMP | FILE ) FILE
{
  test -n "$2" || set -- "$1" "$1"
  touch -t "$(timestamp2touch "$1")" "$2"
}

date_iso() # Ts [date|hours|minutes|seconds|ns]
{
  test -n "${2-}" || set -- "${1-}" date
  test -n "$1" && {
    $gdate -d @$1 --iso-8601=$2 || return $?
  } || {
    $gdate --iso-8601=$2 || return $?
  }
}

# NOTE: BSD date -v style TAG-values are used, translated to GNU date -d
date_fmt_darwin() # TAGS DTFMT
{
  test -n "$1" && tags=$(printf -- '-v %s ' $1) || tags=
  date $date_flags $tags +"$2"
}

# Allow some abbrev. from BSD/Darwin date util with GNU date
bsd_date_tag ()
{
  $gsed \
     -e 's/[0-9][0-9]*s\b/&ec/g' \
     -e 's/[0-9][0-9]*M\b/&in/g' \
     -e 's/[0-9][0-9]*[Hh]\b/&our/g' \
     -e 's/[0-9][0-9]*d\b/&ay/g' \
     -e 's/[0-9][0-9]*w\b/&eek/g' \
     -e 's/[0-9][0-9]*m\b/&onth/g' \
     -e 's/[0-9][0-9]*y\b/&ear/g' \
     -e 's/\<7d\>/1week/g'
}

# Format path for date, default pattern: "$1/%Y/%m/%d.ext" for dirs, or
# "$dirname/%Y/%m/%d/$name.ext" for fiels
archive_path() # Y= M= D= . Dir [Date]
{
  test -d "$1" &&
    ARCHIVE_DIR="$1" || {
      NAME="$(basename "$1" $EXT)"
      ARCHIVE_DIR="$(dirname "$1")"
    }
  shift
  fnmatch "*/" "$ARCHIVE_DIR" && ARCHIVE_DIR="$(strip_trail "$ARCHIVE_DIR")"

  test -z "$1" || now=$1
  test -n "$Y" || Y=/%Y
  test -n "$M" || M=/%m
  test -n "$D" || D=/%d

  test -z "$NAME" || NAME=-$NAME
  export archive_path_fmt=$ARCHIVE_DIR$Y$M$D$NAME$EXT
  test -z "$now" &&
      export archive_path=$($gdate "+$archive_path_fmt") ||
      export archive_path=$(date_fmt "$now" "$archive_path_fmt")
}

datelink() # Date Format Target-Path
{
  test -z "$1" && datep=$(date "+$2") || datep=$(date_fmt "$1" "$2")
  target_path=$3
  test -d "$(dirname $3)" || error "Dir $(dirname $3) must exist" 1
  test -L $target_path && {
    test "$(readlink $target_path)" = "$(basename $datep)" && {
        return
    }
    printf "Deleting "
    rm -v $target_path
  }
  mkrlink $datep $target_path
}

# Print ISO-8601 datetime with minutes precision
datet_isomin() { date_iso "${1-}" minutes; }

# Print ISO-8601 datetime with nanosecond precision
datet_isons() { date_iso "$1" ns; }

# Print fractional seconds since Unix epoch
epoch_microtime() { $gdate +"%s.%N"; }

date_microtime() { $gdate +"%Y-%m-%d %H:%M:%S.%N"; }

sec_nomicro()
{
  fnmatch "*.*" "$1" && {
      echo "$1" | cut -d'.' -f1
  } || echo "$1"
}

date_parse()
{
  test -n "${2-}" || set -- "$1" "%s"
  fnmatch "[0-9][0-9][0-9][0-9][0-9]*[0-9]" "$1" && {
    $gdate -d "@$1" +"$2"
    return $?
  } || {
    $gdate -d "$1" +"$2"
    return $?
  }
}

# Make ISO-8601 for given date or ts and remove all non-numeric chars except '-'
date_id () # <Datetime-Str>
{
  s= p= act=date_autores foreach_${foreach-"do"} "$@" | tr -d ':-' | tr 'T' '-'
}

# Parse compressed datetime spec (Y-M-DTHMs.ms+TZ) to ISO format
date_idp () # <Date-Id>
{
  foreach "$@" | $gsed -E \
      -e 's/^([0-9]{4})([0-9]{2})([0-9]{2})-([0-9]{2})([0-9]{2})([0-9]{2})/\1-\2-\3T\4:\5:\6/' \
      -e 's/^([0-9]{4})([0-9]{2})([0-9]{2})-([0-9]{2})([0-9]{2})/\1-\2-\3T\4:\5/' \
      -e 's/^([0-9]{4})([0-9]{2})([0-9]{2})-([0-9]{2})/\1-\2-\3T\4/' \
      -e 's/^([0-9]{4})([0-9]{2})([0-9]{2})/\1-\2-\3/' \
      -e 's/T([0-9]{2})([0-9]{2})([0-9]{2})$/T\1:\2:\3/' \
      -e 's/T([0-9]{2})([0-9]{2})/T\1:\2/' \
      -e 's/(-[0-9]{2}-[0-9]{2})([+-][0-9:]{2,5})$/\1T00\2/'
}

# Take compressed date-tstat format and parse to ISO-8601 again, local time
date_pstat ()
{
  test "$1" = "-" && echo "$1" || date_parse "$(date_idp "$1")"
}

# Time for function executions
time_fun()
{
  local ret=
  time_exec_start=$(gdate +"%s.%N")
  "$@" || ret=$?
  time_exec=$({ gdate +"%s.%N" | tr -d '\n' ; echo " - $time_exec_start"; } | bc)
  note "Executing '$*' took $time_exec seconds"
  return $ret
}

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

#
