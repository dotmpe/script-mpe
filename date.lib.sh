#!/bi


# Age in seconds
_5MIN=300
_1HOUR=3600
_3HOUR=10800
_6HOUR=64800
_1DAY=86400
_1WEEK=604800


# newer-than FILE SECONDS
newer_than()
{
  test -n "$1" || error "newer-than expected path" 1
  test -e "$1" || error "newer-than expected existing path" 1
  test -n "$2" || error "newer-than expected timestamp argument" 1
  test -z "$3" || error "newer-than surplus arguments" 1
  test $(( $(date +%s) - $2 )) -lt $(filemtime $1) && return 0 || return 1
}

# older-than FILE SECONDS
older_than()
{
  test -n "$1" || error "older-than expected path" 1
  test -e "$1" || error "older-than expected existing path" 1
  test -n "$2" || error "older-than expected timestamp argument" 1
  test -z "$3" || error "older-than surplus arguments" 1
  test $(( $(date +%s) - $2 )) -gt $(filemtime $1) && return 0 || return 1
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
case "$(uname)" in Darwin )
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
    case "$uname" in
        Darwin ) gdate +%s%N ;;
        Linux ) date +%s%N ;;
    esac
}

date_microtime()
{
    case "$uname" in
        Darwin ) gdate +"%Y-%m-%d %H:%M:%S.%N" ;;
        Linux ) gdate +"%Y-%m-%d %H:%M:%S.%N" ;;
    esac
}

date_iso()
{
    case "$uname" in
        Darwin ) gdate --iso ;;
        Linux ) date --iso ;;
    esac
}

datetime_iso()
{
    case "$uname" in
        Darwin ) gdate --iso=minutes ;;
        Linux ) date --iso=minutes ;;
    esac
}


