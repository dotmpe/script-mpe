#!/bin/sh

set -e

test -n "$PREFIX" || PREFIX=$HOME


#TERM=xterm
. $PREFIX/bin/std.sh
. $PREFIX/bin/os.sh
. $PREFIX/bin/str.sh
. $PREFIX/bin/doc.sh


# test for var decl, io. to no override empty
var_isset()
{
  # Aside from declare or typeset in newer reincarnations, 
  # in posix or modern Bourne mode this seems to work best:
  set | grep '\<'$1'=' >/dev/null 2>/dev/null && return
  return 1
}

# No-Op(eration)
noop()
{
  . /dev/null # source empty file
  #echo -n # echo nothing
  #set -- # clear arguments (XXX set nothing?)
}

short()
{
  test -n "$1" || set -- "$(pwd)"
  # XXX maybe replace python script sometime
  $PREFIX/bin/short-pwd.py -1 "$1"
}

test_out()
{
  test -n "$1" || error test_out 1
  local val="$(echo $(eval echo "\$$1"))"
  test -z "$val" || eval echo "\\$val"
}

list_functions()
{
  test -n "$1" || set -- $0
  for file in $*
  do
    test_out list_functions_head
    grep '^[A-Za-z0-9_\/-]*()$' $file
    test_out list_functions_tail
  done
}

# FIXME: testing..
pushd_cwdir()
{
  test -n "$CWDIR" -a "$CWDIR" != "$(pwd)" && {
    echo "pushd $CWDIR" "$(pwd)"
    pushd $WDIR
  } || set --
}

popd_cwdir()
{
  test -n "$CWDIR" -a "$CWDIR" = "$(pwd)" && {
    echo "popd $CWDIR" "$(pwd)"
    test "$(popd)" = "$CWDIR"
  } || set --
}

func_exists()
{
  type $1 2> /dev/null 1> /dev/null || return $?
  # XXX bash/bsd-darwin: test "$(type -t $1)" = "function" && return
  return 0
}

try_exec_func()
{
  test -n "$1" || return 1
  func_exists $1 || return $?
  $1 || return $?
}

# 1:file-name[:line-number] 2:content
file_insert_at()
{
  test -x "$(which ed)" || error "'ed' required" 1

  test -n "$*" || error "arguments required" 1

  local file_name= line_number=
  fnmatch "*:[0-9]*" $1 && {
    file_name=$(echo $1 | sed 's/:\([0-9]\+\)$//')
    line_number=$(echo $1 | sed 's/^\(.*\):\([0-9]\+\)$/\2/')
    shift 1
  } || {
    file_name=$1; shift 1
    line_number=$1; shift 1
  }

  test -n "$*" || error "nothing to insert" 1
  test -e "$file_name" || error "no file $file_name" 1

  # use ed-script to insert second file into first at line
  note "Inserting at $file_name:$line_number"
  echo "${line_number}a
$1
.
w" | ed $file_name $tmpf
}

# 
# 1:where-grep 2:file-path
file_where_before()
{
  test -n "$1" || error "where-grep required" 1
  test -n "$2" || error "file-path required" 1
  where_line=$(grep -n "$@")
  line_number=$(( $(echo "$where_line" | sed 's/^\([0-9]\+\):\(.*\)$/\1/') - 1 ))
}

# 1:where-grep 2:file-path 3:content
file_insert_where_before()
{
  local where_line= line_number=
  test -e "$2" || error "no file $2" 1
  test -n "$3" || error "contents required" 1
  file_where_before "$1" "$2"
  test -n "$where_line" || {
    error "missing or invalid file-insert sentinell for where-grep:$1 (in $2)" 1
  }
  file_insert_at $2:$line_number "$3"
}

get_uuid()
{
  test -e /proc/sys/kernel/random/uuid && {
    cat /proc/sys/kernel/random/uuid
    return 0
  }
  test -x $(which uuidgen) && {
    uuidgen
    return 0
  }
  error "FIXME uuid required" 1
  return 1
}

