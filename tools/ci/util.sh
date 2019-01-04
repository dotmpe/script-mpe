#!/usr/bin/env bash
test -z "${ci_util_:-}" && ci_util_=1 || exit 98 # Recursion

: "${ci_stages:=}"
: "${stages_done:=}"

export_stage()
{
  test -n "${1:-}" || return 100
  test -n "${2:-}" || set -- "$1" "$1"

  export scriptname=$1 stage=$1 stage_id=$2 ${2}_ts="$($gdate +%s.%N)"
  ci_stages="$ci_stages $stage_id"
}

announce_stage()
{
  test $# -le 2 || return 98

  test -n "${1:-}" || set -- "$stage"
  test -n "${2:-}" || set -- "$1" "$stage_id"
  test -n "$2" || set -- "$1" "$1"

  print_yellow "$scriptname:$stage" "Starting stage... ($($gdate --iso=ns -d @$(eval echo \$${2}_ts)))"
}

close_stage()
{
  test -n "${1:-}" || set -- "Done"

  export ${stage_id}_end_ts="$($gdate +%s.%N)"
  stages_done="$stages_done $stage_id"
  print_yellow "$stage" "$1 ($($gdate --iso=ns))"
}

ci_announce()
{
  print_yellow "$scriptname:$stage" "$1 ($($gdate --iso=ns))"
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
