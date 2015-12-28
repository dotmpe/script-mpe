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


