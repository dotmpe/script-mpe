#!/bin/sh

set -e

test -n "$PREFIX" || PREFIX=$HOME


#TERM=xterm
. $PREFIX/bin/std.sh
. $PREFIX/bin/os.lib.sh
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
#cmd_exists pushd || {
#pushd()
#{
#  tmp=/tmp/pushd-$$
#  echo "pushd \$\$=$$ $@"
#  echo "$1" >>$tmp
#  cd $1
#}
#popd()
#{
#  tmp=/tmp/pushd-$$
#  echo "popd \$\$=$$ $@"
#  tail -n 1 $tmp
#  cd $(truncate_trailing_lines $tmp 1)
#}
#}
#
#pushd_cwdir()
#{
#  test -n "$CWDIR" -a "$CWDIR" != "$(pwd)" && {
#    echo "pushd $CWDIR" "$(pwd)"
#    pushd $WDIR
#  } || set --
#}
#
#popd_cwdir()
#{
#  test -n "$CWDIR" -a "$CWDIR" = "$(pwd)" && {
#    echo "popd $CWDIR" "$(pwd)"
#    test "$(popd)" = "$CWDIR"
#  } || set --
#}

cmd_exists()
{
  test -x $(which $1) || return $?
}

func_exists()
{
  type $1 2> /dev/null 1> /dev/null || return $?
  # XXX bash/bsd-darwin: test "$(type -t $1)" = "function" && return
  return 0
}

try_exec_func()
{
  test -n "$1" || return 97
  func_exists $1 || return $?
  local func=$1
  shift 1
  $func "$@" || return $?
}

# 1:file-name[:line-number] 2:content
file_insert_at()
{
  test -x "$(which ed)" || error "'ed' required" 1

  test -n "$*" || error "arguments required" 1

  local file_name= line_number=
  fnmatch *:[0-9]* "$1" && {
    file_name=$(echo $1 | cut -f 1 -d :)
    line_number=$(echo $1 | cut -f 2 -d :)
    shift 1
  } || {
    file_name=$1; shift 1
    line_number=$1; shift 1
  }

  test -e "$file_name" || error "no file $file_name" 1
  test -n "$1" || error "content expected" 1
  test -n "$*" || error "nothing to insert" 1

  # use ed-script to insert second file into first at line
  note "Inserting at $file_name:$line_number"
  echo "${line_number}a
$1
.
w" | ed $file_name $tmpf
}

file_replace_at()
{
  test -n "$*" || error "arguments required" 1

  local file_name= line_number=

  fnmatch *:[0-9]* "$1" && {
    file_name=$(echo $1 | cut -f 1 -d :)
    line_number=$(echo $1 | cut -f 2 -d :)
    shift 1
  } || {
    file_name=$1; shift 1
    line_number=$1; shift 1
  }

  test -e "$file_name" || error "no file $file_name" 1
  test -n "$line_number" || error "no line_number" 1
  test -n "$1" || error "nothing to insert" 1

  sed $line_number's/.*/'$1'/' $file_name
}

#
# 1:where-grep 2:file-path
file_where_before()
{
  test -n "$1" || error "where-grep required" 1
  test -n "$2" || error "file-path required" 1
  where_line=$(grep -n "$@")
  line_number=$(( $(echo "$where_line" | sed 's/^\([0-9]*\):\(.*\)$/\1/') - 1 ))
}

# 1:where-grep 2:file-path 3:content
file_insert_where_before()
{
  local where_line= line_number=
  test -e "$2" || error "no file $2" 1
  test -n "$3" || error "contents required" 1
  file_where_before "$1" "$2"
  test -n "$where_line" || {
    error "missing or invalid file-insert sentinel for where-grep:$1 (in $2)" 1
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

expr_substr()
{
    test -n "$expr" || error "expr init req" 1
    case "$expr" in
        sh-substr )
            expr substr "$1" "$2" "$3" ;;
        bash-substr )
            bash -c 'MYVAR=_"'"$1"'"; printf -- "${MYVAR:'$2':'$3'}"' ;;
        * ) error "unable to substr $expr" 1
    esac
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

xsed_rewrite()
{
    case "$uname" in
        Darwin ) sed -i.applyBack "$@";;
        Linux ) sed "$@";;
    esac
}

on_host()
{
  test "$hostname" = "$1" || return 1
}

req_host()
{
  on_host "$1" || error "$0 runs on $1 only" 1
}

on_system()
{
  test "$uname" = "$1" || return 1
}

run_cmd()
{
  test -n "$1" || set -- "$hostname" "$2"
  test -n "$2" || set -- "$1" "whoami"
  test -n "$host_addr_info" || host_addr_info=$hostname

  test -z "$dry_run" && {
    on_host $1 && {
      $2 \
        && debug "Executed locally: '$2'" \
        || err "Error executing local command: '$2'" 1
    } || {
      ssh $host_addr_info "$2" \
        && debug "Executed at $host_addr_info: '$2'" \
        || err "Error executing command at $host_addr_info: '$2'" 1
    }
    return $?
  } || {
    echo "on_host $1 && { '$2'..} || { ssh $host_addr_info '$2'.. }"
  }
}

ssh_req()
{
  test -n "$host_addr_info" || {
    test -n "$1" || set -- "$hostname" "$2"
    test -n "$2" || set -- "$1" "$(whoami)"
    host_addr_info="$1"
    test -z "$2" || host_addr_info="$2"'@'$host_addr_info
    note "Connecting to $host_addr_info"
  }
}

wait_for()
{
  test -n "$1" || set -- "$hostname"
  while [ 1 ]
  do
    ping -c 1 $1 >/dev/null 2>/dev/null && break
    note "Waiting for $1.."
    sleep 7
  done
}

# Wrap wc but handle with or w.o. trailing posix line-end
line_count()
{
  lc="$(echo $(od -An -tc -j $(( $(filesize $1) - 1 )) $1))"
  case "$lc" in "\n" ) ;;
    "\r" ) error "POSIX line-end required" 1 ;;
    * ) printf "\n" >>$1 ;;
  esac
  local lc=$(wc -l $1 | awk '{print $1}')
  echo $lc
}

truncate_trailing_lines()
{
  test -n "$1" || error "FILE expected" 1
  test -n "$2" || error "LINES expected" 1
  test $2 -gt 0 || error "LINES > 0 expected" 1
  local lines=$(line_count "$1")
  cp $1 $1.tmp
  tail -n $2 $1.tmp
  head -n +$(( $lines - $2 )) $1.tmp > $1
  rm $1.tmp
}

# find '<func>()' line and see if its preceeded by a comment. Return comment text.
func_comment()
{
  test -n "$1" || error "function name expected" 1
  test -e "$2" || error "file expected: '$2'" 1
  test -z "$3" || error "surplus arguments: '$3'" 1
  grep_line="$(grep -n "^$1()" "$2" | cut -d ':' -f 1)"
  case "$grep_line" in [0-9]* ) ;; * ) return 0;; esac
  func_leading_line="$(head -n +$(( $grep_line - 1 )) "$2" | tail -n 1)"
  echo "$func_leading_line" | grep -q '^\s*#\ ' && {
    echo "$func_leading_line" | sed 's/^\s*#\ //'
  } || noop
}


