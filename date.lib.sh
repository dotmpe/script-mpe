#!/bin/sh


date_lib_load()
{
  TODAY=+%y%m%d0000

  # Age in seconds
  _1MIN=60
  _2MIN=120
  _3MIN=180
  _4MIN=240
  _5MIN=300
  _10MIN=600
  _45MIN=2700

  _1HOUR=3600
  _3HOUR=10800
  _6HOUR=64800

  _1DAY=86400
  _1WEEK=604800

  # Note: what are the proper lengths for month and year? It does not matter that
  # much if below is only used for fmtdate-relative.
  _1MONTH=$(( 4 * $_1WEEK ))
  _1YEAR=$(( 365 * $_1DAY ))

  case "$uname" in
    Darwin ) gdate=gdate ;;
    Linux ) Gdate=date ;;
  esac
}

# newer-than FILE SECONDS
newer_than()
{
  test -n "$1" || error "newer-than expected path" 1
  test -e "$1" || error "newer-than expected existing path" 1
  test -n "$2" || error "newer-than expected delta seconds argument" 1
  test -z "$3" || error "newer-than surplus arguments" 1
  test $(( $(date +%s) - $2 )) -lt $(filemtime "$1") && return 0 || return 1
}

# older-than FILE SECONDS
older_than()
{
  test -n "$1" || error "older-than expected path" 1
  test -e "$1" || error "older-than expected existing path" 1
  test -n "$2" || error "older-than expected delta seconds argument" 1
  test -z "$3" || error "older-than surplus arguments" 1
  test $(( $(date +%s) - $2 )) -gt $(filemtime "$1") && return 0 || return 1
}

# given timestamp, display a friendly X sec/min/hr/days/weeks/months/years ago
# message.
fmtdate_relative() # [ Previous-Timestamp | ""] [Delta] [suffix]
{
	test -n "$2" || set -- "$1" "$(( $(date +%s) - $1 ))" "$3"
	test -n "$3" || set -- "$1" "$2" " ago"
	local ts=$1 timed=$2

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
      tags=$(for tag in $1; do echo "-v $tag"; done)
      date $date_flags $tags +"$2"
    }
    ;;
  Linux )
    date_fmt() {
      # NOTE patching for GNU date
      tags=$(for tag in $1; do echo "-d $tag" \
          | sed 's/1d/1day/g' \
          | sed 's/7d/1week/g'; done)
      date $date_flags $tags +"$2"
    }
    ;;
esac

datelink()
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
