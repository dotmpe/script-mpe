#!/usr/bin/env bash
test -z "${ci_util_:-}" && ci_util_=1 || exit 98 # Recursion

: "${ci_stages:=}"
: "${stages_done:=}"

export_stage()
{
  test -n "${1:-}" || return 100
  test -n "${2:-}" || set -- "$1" "$1"

  export stage=$1 stage_id=$2 ${2}_ts="$($gdate +%s.%N)"
  ci_stages="$ci_stages $stage_id"
}

announce_stage()
{
  test $# -le 2 || return 98

  test -n "${1:-}" || set -- "$stage"
  test -n "${2:-}" || set -- "$1" "$stage_id"
  test -n "$2" || set -- "$1" "$1"

  local ts="$(eval echo \$${2}_ts)"
  deltamicro="$(echo "$ts - $travis_ci_timer_ts" | bc )"
  print_yellow "$scriptname:$stage" "$deltamicro sec: Starting stage..."
}

close_stage()
{
  test -n "${1:-}" || set -- "Done"

  local ts=$($gdate +%s.%N)
  export ${stage_id}_end_ts="$ts"
  stages_done="$stages_done $stage_id"
  deltamicro="$(echo "$ts - $travis_ci_timer_ts" | bc )"
  print_yellow "$scriptname:$stage" "$deltamicro sec: $1"
}

ci_announce()
{
  local ts=$($gdate +%s.%N)
  deltamicro="$(echo "$ts - $travis_ci_timer_ts" | bc )"
  print_yellow "$scriptname:$stage" "$deltamicro sec: $1"
}

ci_bail()
{
  test $# -eq 1 || return
  print_red "$1" >&2 ; return 1
}

ci_abort()
{
  test $# -eq 1 || return
  print_red "$1" >&2 ; exit 1
}

#
