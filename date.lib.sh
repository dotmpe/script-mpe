#!/bin/sh

# shellcheck disable=SC2015,SC2154,SC2086,SC205,SC2004,SC2120,SC2046,2059
# See htd.sh for shellcheck descriptions

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

  case "$uname" in
    Darwin ) gdate="gdate" ;;
    Linux ) gdate="date" ;;
  esac
  export gdate
}

# newer-than FILE SECONDS, filemtime must be greater-than Now - SECONDS
newer_than()
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

# given timestamp, display a friendly X sec/min/hr/days/weeks/months/years ago
# message.
fmtdate_relative() # [ Previous-Timestamp | ""] [Delta] [suffix]
{
    # Calculate delta based on now
  test -n "$2" || set -- "$1" "$(( $(date +%s) - $1 ))" "$3"
    # Set default suffix
  test -n "$3" -o -z "$datefmt_suffix" || set -- "$1" "$2" "$datefmt_suffix"
  test -n "$3" || set -- "$1" "$2" " ago"
  timed=$2

  if test $timed -gt $_1YEAR
  then

    if test $timed -lt $(( $_1YEAR + $_1YEAR ))
    then
      printf -- "one year$3"
    else
      printf -- "$(( $timed / $_1YEAR )) years$3"
    fi
  else

    if test $timed -gt $_1MONTH
    then

      if test $timed -lt $(( $_1MONTH + $_1MONTH ))
      then
        printf -- "a month$3"
      else
        printf -- "$(( $timed / $_1MONTH )) months$3"
      fi
    else

      if test $timed -gt $_1WEEK
      then

        if test $timed -lt $(( $_1WEEK + $_1WEEK ))
        then
          printf -- "a week$3"
        else
          printf -- "$(( $timed / $_1WEEK )) weeks$3"
        fi
      else

        if test $timed -gt $_1DAY
        then

          if test $timed -lt $(( $_1DAY + $_1DAY ))
          then
            printf -- "a day$3"
          else
            printf -- "$(( $timed / $_1DAY )) days$3"
          fi
        else

          if test $timed -gt $_1HOUR
          then

            if test $timed -lt $(( $_1HOUR + $_1HOUR ))
            then
              printf -- "an hour$3"
            else
              printf -- "$(( $timed / $_1HOUR )) hours$3"
            fi
          else

            if test $timed -gt $_1MIN
            then

              if test $timed -lt $(( $_1MIN + $_1MIN ))
              then
                printf -- "a minute$3"
              else
                printf -- "$(( $timed / $_1MIN )) minutes$3"
              fi
            else

              printf -- "$timed seconds$3"

            fi
          fi
        fi
      fi
    fi
  fi
}

timestamp2touch()
{
  test -n "$1" || set -- "$(date +%s)"
  date_flags="-r $1" \
    date_fmt "" %y%m%d%H%M.%S
}

# TS FILE
touch_ts()
{
  touch -t $(timestamp2touch $1) $2
}

# TAGS DTFMT
# NOTE: BSD date -v style TAG-values are used, translated to GNU date -d
case "$(uname)" in

  Darwin )
    date_fmt() {
      test -n "$1" && tags=$(printf -- '-v %s ' $1) || tags=
      date $date_flags $tags +"$2"
    }
    ;;
  Linux )
    date_fmt() {
      # NOTE patching for GNU date
      test -n "$1" && tags=$(printf -- '-d %s ' $1 \
          | sed 's/1d/1day/g' \
          | sed 's/7d/1week/g') || tags=
      date $date_flags $tags +"$2"
    }
    ;;
esac

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

epoch_microtime()
{
  $gdate +%s%N
}

date_microtime()
{
  $gdate +"%Y-%m-%d %H:%M:%S.%N"
}

date_iso()
{
  $gdate --iso
}

datetime_iso()
{
  test -n "$1" && {
    $gdate -d @$1 --iso=minutes || return $?
  } || {
    $gdate --iso=minutes || return $?
  }
}
