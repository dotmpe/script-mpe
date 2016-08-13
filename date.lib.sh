#!/bin/sh


# Age in seconds
_5MIN=300
_1HOUR=3600
_3HOUR=10800
_6HOUR=64800
_1DAY=86400
_1WEEK=604800


younger_than()
{
  test -n "$1" || error "younger-than expected path" 1
  test -e "$1" || error "younger-than expected existing path" 1
  test -n "$2" || error "younger-than expected timestamp argument" 1
  test -z "$3" || error "younger-than surplus arguments" 1
  test $(( $(date +%s) - $2 )) -lt $(filemtime $1) && return 0 || return 1
}

older_than()
{
  test -n "$1" || error "older-than expected path" 1
  test -e "$1" || error "older-than expected existing path" 1
  test -n "$2" || error "older-than expected timestamp argument" 1
  test -z "$3" || error "older-than surplus arguments" 1
  test $(( $(date +%s) - $2 )) -gt $(filemtime $1) && return 0 || return 1
}


# TODO: move date routines to lib
# NOTE: these use BSD date -v, see GNU date -d
case "$(uname)" in Darwin )
    date_fmt() {
      tags=$(for tag in $1; do echo "-v $tag"; done)
      date $tags +"$2"
    }
    ;;
  Linux )
    date_fmt() {
      # NOTE patching for GNU date
      tags=$(for tag in $1; do echo "-d $tag" \
          | sed 's/1d/1day/g' \
          | sed 's/7d/1week/g'; done)
      date $tags +"$2"
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

