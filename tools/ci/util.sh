#!/bin/sh

export_stage() {
  test -n "$1" || return 100
  test -n "$2" || set -- "$1" "$1"
  export scriptname=$1 stage=$1 stage_id=$2 ${2}_ts="$(date +%s.%N)"
}
announce_stage() {
  test -n "$1" || set -- "$stage"
  test -n "$2" || set -- "$1" "$stage_id"
  test -n "$2" || set -- "$1" "$1"
  echo "--- Starting '$stage'... ($(date --iso=ns -d @$(eval echo \$${2}_ts)))"
}
announce()
{
  echo "---------- $1 ($(date --iso=ns))"
}

# No error on empty, or not trueish match
not_trueish()
{
  test -n "$1" || return 0
  trueish "$1" && return 1 || return 0
}

#
