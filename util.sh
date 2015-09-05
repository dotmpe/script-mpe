#!/bin/sh

test -n "$PREFIX" || PREFIX=$HOME

TERM=xterm
. $PREFIX/bin/std.sh
. $PREFIX/bin/os.sh
. $PREFIX/bin/str.sh
. $PREFIX/bin/doc.sh


echo () (
  fmt=%s end=\\n IFS=" "
  
  while [ $# -gt 1 ] ; do
    case "$1" in
      [!-]*|-*[!ne]*) break ;;
      *ne*|*en*) fmt=%b end= ;;
      *n*) end= ;;
      *e*) fmt=%b ;;
    esac
    shift
  done
  
  printf "$fmt$end" "$*"
)


#
req_arg()
{
  label=$(eval echo \${req_arg_$4[0]})
  varname=$(eval echo \${req_arg_$4[1]})
  test -n "$1" || {
    warn "$2 requires argument at $3 '$label'"
    return 1
  }
  test -n "$varname" && {
    export $varname="$1"
  } || {
    export $4="$1"
  }
}

# FIXME: testing..
pushd_cwdir()
{
  test -n "$CWDIR" -a "$CWDIR" != "$(pwd)" && {
    echo "pushd $CWDIR" "$(pwd)"
    pushd $WDIR
  } || echo -n
}

popd_cwdir()
{
  test -n "$CWDIR" -a "$CWDIR" = "$(pwd)" && {
    echo "popd $CWDIR" "$(pwd)"
    test "$(popd)" = "$CWDIR"
  } || echo -n
}

# Get help str if exists for $section $id
# 1:section-number 2:help-id
# :*:help_descr
try_help()
{
  help_descr=$(eval echo "\$man_$(echo $1)$(echo $2)")
  echo $help_descr
}

# Run through all help sections for given string
# 1:str
# :
echo_help()
{
  mkid _$1
  try_help 1 $id && return # commands
  try_help 5 $id && return # config files
  try_help 7 $id && return # overview, conventions, misc.
}

# Find shell script location with or without extension
# 1:basename:scriptname
# :fn
locate_name()
{
  [ -n "$1" ] && fn=$1 || fn=$(which $scriptname)
  [ -n "$fn" ] || fn=$(which $scriptname.sh)
  [ -n "$fn" ] || return 1
}

try_exec_func()
{
  test -n "$1" || return 1
  type $1 2>&1 1> /dev/null || return $?
  $1 || return $?
}

try_load()
{
  local r
  try_exec_func load || {
    r=$?; test -n "$1" || return $?;
  }
  test -n "$1" || return
  try_exec_func ${1}_load || r=$?
  return $r
}

try_usage()
{
  try_exec_func && return
  test -n "$1" || return 1
  try_exec_func ${1}_usage || return $?
}


