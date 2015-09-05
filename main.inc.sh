#!/bin/sh


# cmd function name from first argument,
test -n "$cmd" || {
  if test -n "$1"; then
    cmd=${cmd_pref}$1${cmd_suf}
    shift 1
  else
    if test -n "$cmd_def"; then
      cmd=${cmd_pref}${cmd_def}${cmd_suf}
    fi
  fi
}
test -n "$func" || {
    test -n "$func_pref" || func_pref=c_
    func=$(echo ${func_pref}$cmd${func_suf} | tr '-' '_')
}
func_exists=""


# load/exec if func exists
type $func > /dev/null && {
  func_exists=y
  try_load $base
  $func $@
  e=0
} || {
  # handle non-zero return or print usage for non-existant func
  e=$?
  test -n "$func_exists" \
    && error "Command $cmd returned $e" $e
  try_usage $base
  test -z "$cmd" && {
    error 'No command given' 1
  } || {
    error "No such command: $cmd" 2
  }
}

