#!/bin/sh

test -n "$PREFIX" || PREFIX=$HOME

TERM=xterm
. $PREFIX/bin/std.sh
. $PREFIX/bin/os.sh
. $PREFIX/bin/str.sh
. $PREFIX/bin/doc.sh


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
  } || set --
}

popd_cwdir()
{
  test -n "$CWDIR" -a "$CWDIR" = "$(pwd)" && {
    echo "popd $CWDIR" "$(pwd)"
    test "$(popd)" = "$CWDIR"
  } || set --
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
  try_help 1 $id && return || \ # commands
  try_help 5 $id && return || \ # config files
  try_help 7 $id && return  # overview, conventions, misc.
}

# Find shell script location with or without extension
# 1:basename:scriptname
# :fn
locate_name()
{
  local name=
  [ -n "$1" ] && name=$1 || name=$scriptname
  [ -n "$name" ] || error "script name required" 1
  fn=$(which $name)
  [ -n "$fn" ] || fn=$(which $name.sh)
  [ -n "$fn" ] || return 1
}

try_exec_func()
{
  test -n "$1" || return 1
  type $1 2> /dev/null 1> /dev/null || return $?
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
  where_line=$(grep -n $1 $2)
  line_number=$(( $(echo $where_line | sed 's/^\([0-9]\+\):\(.*\)$/\1/') - 1 ))
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
    return
  }
  test -x $(which uuidgen) && {
    uuidgen
    return
  }
  error "FIXME uuid required" 1
  return 1
}

