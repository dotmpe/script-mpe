#!/bin/sh

incr_c()
{
  c=$(( $c + 1 ))
}

func_exists()
{
  type $1 >/dev/null 2>/dev/null && return
  # XXX bash/bsd-darwin: test "$(type -t $1)" = "function" && return
  return 1
}

# test for var decl, io. to no override empty
var_isset()
{
  set | grep '\<'$1'=' >/dev/null 2>/dev/null && return
  return 1
}

get_subcmd_name()
{
  # subcmd function name from first argument,
  test -n "$subcmd_name" || {
    if test -n "$1"; then
      subcmd_name=${subcmd_pref}$1${subcmd_suf}
      incr_c
    else
      if test -n "$subcmd_def"; then
        subcmd_name=${subcmd_pref}${subcmd_def}${subcmd_suf}
      fi
    fi
  }
}

get_subcmd_func_name()
{
  test -n "$subcmd_func" || {
      var_isset subcmd_func_pref || subcmd_func_pref=c_
      subcmd_func=$(echo ${subcmd_func_pref}${subcmd_name}${subcmd_func_suf} \
          | tr '-' '_')
  }
}

main_load()
{
  local r=
  try_exec_func load || {
    r=$?; test -n "$1" || error "std load failed" $r
  }
  test -n "$1" || return
  try_exec_func ${1}_load || error "${1} load failed" $?
}

main_usage()
{
  try_exec_func usage && return
  test -n "$1" || return 1
  try_exec_func ${1}_usage || return $?
}

#  local scriptname= base=

#  local subcmd_def=
#  local subcmd_pref= subcmd_suf=
#  local subcmd_func_pref= subcmd_func_suf=

main()
{
  local subcmd_name= subcmd_func= e= c=0

  get_subcmd_name $*
  test $c -gt 0 && shift $c ; c=0
  get_subcmd_func_name

  main_load $base

  debug "$base loaded"

  func_exists $subcmd_func || {

    main_usage $base

    test -z "$subcmd_name" && {
      error 'No command given' 1
    } || {
      error "No such command: $subcmd_name" 2
    }
  }

  debug "starting $scriptname $subcmd_name"

  $subcmd_func $* && {
    info "$subcmd_name:-$subcmd_def  completed"
  } || {
    e=$?
    error "Command $subcmd_name returned $e" $e
  }
}

