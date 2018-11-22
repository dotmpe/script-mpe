#!/bin/sh


date_lib_load()
{
  export TODAY=+%y%m%d0000

  # Age in seconds
  export _1MIN=60
  export _2MIN=120
  export _3MIN=180
  export _4MIN=240
  export _5MIN=300
  export _10MIN=600
  export _45MIN=2700

  export _1HOUR=3600
  export _3HOUR=10800
  export _6HOUR=64800

  export _1DAY=86400
  export _1WEEK=604800

  # Note: what are the proper lengths for month and year? It does not matter that
  # much if below is only used for fmtdate-relative.
  export _1MONTH=$(( 4 * $_1WEEK ))
  export _1YEAR=$(( 365 * $_1DAY ))

  date_lib_init_bin
}


date_lib_init_bin()
{
  case "$uname" in
    Darwin ) gdate="gdate" ;;
    Linux ) gdate="date" ;;
  esac
  export gdate
}


# newer-than FILE SECONDS, filemtime must be greater-than Now - SECONDS
newer_than() # FILE SECONDS
{
  test -n "$1" || error "newer-than expected path" 1
  test -e "$1" || error "newer-than expected existing path" 1
  test -n "$2" || error "newer-than expected delta seconds argument" 1
  test -z "$3" || error "newer-than surplus arguments" 1
  test $(( $(date +%s) - $2 )) -lt $(filemtime "$1")
}

# older-than FILE SECONDS, filemtime must be less-than Now - SECONDS
older_than()
{
  test -n "$1" || error "older-than expected path" 1
  test -e "$1" || error "older-than expected existing path" 1
  test -n "$2" || error "older-than expected delta seconds argument" 1
  test -z "$3" || error "older-than surplus arguments" 1
  test $(( $(date +%s) - $2 )) -gt $(filemtime "$1")
}

# given timestamp, display a friendly human readable time-delta:
# X sec/min/hr/days/weeks/months/years ago
fmtdate_relative() # [ Previous-Timestamp | ""] [Delta] [suffix=" ago"]
{
    # Calculate delta based on now
  test -n "$2" || set -- "$1" "$(( $(date +%s) - $1 ))" "$3"
    # Set default suffix
  test -n "$3" -o -z "$datefmt_suffix" || set -- "$1" "$2" "$datefmt_suffix"
  test -n "$3" || set -- "$1" "$2" " ago"

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
  test -n "$1" || set -- "@$(date +%s)"
  test -e "$1" && {
    $gdate -r "$1" +"%y%m%d%H%M.%S"
  } || {
    $gdate -d "$1" +"%y%m%d%H%M.%S"
  }
}

touch_ts() # [ FILE | TIMESTAMP FILE ]
{
  test -n "$2" || set -- "$1" "$1"
  touch -t "$(timestamp2touch "$1")" "$2"
}

# NOTE: BSD date -v style TAG-values are used, translated to GNU date -d
date_fmt_darwin() # TAGS DTFMT
{
  test -n "$1" && tags=$(printf -- '-v %s ' $1) || tags=
  date $date_flags $tags +"$2"
}

# Allow some abbrev. from BSD/Darwin date util with GNU date
bsd_gsed_pre(){
  $gsed \
     -e 's/[0-9][0-9]*s\b/&ec/g' \
     -e 's/[0-9][0-9]*m\b/&in/g' \
     -e 's/[0-9][0-9]*d\b/&ay/g' \
     -e 's/[0-9][0-9]*w\b/&eek/g' \
     -e 's/[0-9][0-9]*y\b/&ear/g' \
     -e 's/\<7d\>/1week/g'
}

date_fmt() # Date-Ref Str-Time-Fmt
{
  test -z "$1" && {
    tags="-d today"
  } || {
    # NOTE patching for GNU date
    _inner_() { printf -- '-d ' ; echo "$1" | bsd_gsed_pre ;}
    test -e "$1" && { tags="-d @$(filemtime "$1")"; } ||
      tags=$( p= s= act=_inner_ foreach_do $1 )
  }
  $gdate $date_flags $tags +"$2"
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

date_iso() # Ts [date|hours|minutes|seconds|ns]
{
  test -n "$2" || set -- "$1" date
  test -n "$1" && {
    $gdate -d @$1 --iso-8601=$2 || return $?
  } || {
    $gdate --iso-8601=$2 || return $?
  }
}

# Print ISO-8601 datetime with minutes precision
datet_isomin() { date_iso "$1" minutes; }

# Print ISO-8601 datetime with nanosecond precision
datet_isons() { date_iso "$1" ns; }

# Print fractional seconds since Unix epoch
epoch_microtime() { $gdate +%s.%N; }

date_microtime() { $gdate +"%Y-%m-%d %H:%M:%S.%N"; }


# Output date at required resolution
date_autores() # Date-Time-Str
{
  fnmatch "[0-9][0-9][0-9][0-9][0-9][0-9][0-9]*[0-9]" "$1" || {
    # Convert date-str to timestamp
    set -- "$( $gdate -d "$1" "+%s" )"
  }

  dt_iso="$(date_iso "$1" minutes)"
  echo "$dt_iso" | sed \
      -e 's/T00:00:00//' \
      -e 's/T00:00//' \
      -e 's/:00$//'
}

date_parse()
{
  test -n "$2" || set -- "$1" "%s"
  fnmatch "[0-9][0-9][0-9][0-9][0-9]*[0-9]" "$1" && {
    $gdate -d "@$1" +"$2"
    return $?
  } || {
    $gdate -d "$1" +"$2"
    return $?
  }
}

# Make ISO-8601 for given date or ts and remove all non-numeric chars except '-'
date_id() {
  test "$1" = "-" && echo "$1" || {
      date_autores "$1" | tr -d ':-' | tr 'T' '-'
  }
}

date_idp() {
  echo "$1" | $gsed -E \
      -e 's/^([0-9]{4})([0-9]{2})([0-9]{2})-([0-9]{2})([0-9]{2})([0-9]{2})/\1-\2-\3T\4:\5:\6/' \
      -e 's/^([0-9]{4})([0-9]{2})([0-9]{2})-([0-9]{2})([0-9]{2})/\1-\2-\3T\4:\5/' \
      -e 's/^([0-9]{4})([0-9]{2})([0-9]{2})-([0-9]{2})/\1-\2-\3T\4/' \
      -e 's/^([0-9]{4})([0-9]{2})([0-9]{2})/\1-\2-\3/' \
      -e 's/T([0-9]{2})([0-9]{2})([0-9]{2})$/T\1:\2:\3/' \
      -e 's/T([0-9]{2})([0-9]{2})/T\1:\2/' \
      -e 's/(-[0-9]{2}-[0-9]{2})([+-][0-9:]{2,5})$/\1T00\2/'
}

# Take compressed date-tstat format and parse to ISO-8601 again, local time
date_pstat() {
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
