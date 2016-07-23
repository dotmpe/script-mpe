#!/bin/sh

# Sys: lower level Sh helpers; dealing with vars, functions, and other shell
# ideosyncracities

set -e



sys_load()
{
  test -n "$TMPDIR" && {
    test -z "$RAM_TMPDIR" && {
      require_fs_casematch $TMPDIR
    } || {
      test -d "$RAM_TMPDIR" || error "Not a dir $RAM_TMPDIR" 1
      require_fs_casematch "$RAM_TMPDIR"
    }
  } || {
    test -d /tmp || error "No /tmp" 1
    export TMPDIR=/tmp
    note "TMPDIR=$TMPDIR"
  }
}


require_fs_casematch()
{
  test -n "$CWD" || CWD="$(pwd -P)"
  test -n "$1" && {
    cd $1
  }
  echo 'ok' > abc
  echo 'notok' > ABC
  test "$(echo $( cat abc ABC))" = "ok notok" && {
    debug "Case-sensitive fs '$1' OK"
    rm abc ABC || noop
  } || {
    test "$(echo $( cat abc ABC))" = "notok notok" && {
      rm abc || noop
      warn "Case-insensitive fs '$1' detected!"
    } || {
      rm abc ABC || noop
      cd $CWD
      error "Unknown error" 1
    }
  }
  cd $CWD
}


incr()
{
  local incr_amount
  test -n "$2" && incr_amount=$2 || incr_amount=1
  v=$(eval echo \$$1)
  export $1=$(( $v + $incr_amount ))
}

# test for var decl, io. to no override empty
var_isset()
{
  # Aside from declare or typeset in newer reincarnations,
  # in posix or modern Bourne mode this seems to work best:
  set | grep '\<'$1'=' >/dev/null 2>/dev/null && return
  return 1
}

# require vars to be initialized, regardless of value
req_vars()
{
  while test $# -gt 0
  do
    var_isset "$1" || return 1
    shift
  done
}

# No-Op(eration)
noop()
{
  . /dev/null # source empty file
  #echo -n # echo nothing
  #printf "" # id. if echo -n incompatible (Darwin)
  #set -- # clear arguments (XXX set nothing?)
}

trueish()
{
  test -n "$1" || return 1
  case "$1" in
		[Oo]n|[Tt]rue|[Yy]|[Yy]es|1)
      return 0;;
    * )
      return 1;;
  esac
}

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

try_var()
{
  local value="$(eval echo "\$$1")"
  test -n "$value" || return 1
  echo $value
}

create_ram_disk()
{
  test -n "$1" || error "Name expected" 1
  test -n "$2" || error "Size expected" 1
  test -z "$3" || error "Surplus arguments '$3'" 1

  case "$uname" in

    Darwin )
        local size=$(( $2 * 2048 ))
        diskutil erasevolume 'Case-sensitive HFS+' \
          "$1" `hdiutil attach -nomount ram://$size`
      ;;

      # Linux
      # mount -t tmpfs -o size=512m tmpfs /mnt/ramdisk

    * )
        error "Unsupported platform '$uname'" 1
      ;;

  esac
}

# setup-tmp [(RAM_)TMPDIR]
setup_tmpd()
{
  test -n "$1" || set -- "$base" "$2"
  test -n "$2" || {
    test -n "$TMPDIR" && set -- "$1" "$TMPDIR" || {
      test -n "$RAM_TMPDIR" || {
        warn "No RAM tmpdir/No tmpdir settings found"
        test -w "/dev/shm" && RAM_TMPDIR=/dev/shm/tmp
      }
    }
    test -n "$RAM_TMPDIR" && set -- "$1" "$RAM_TMPDIR"
  }
  test -d $2/$1 || mkdir -p $2/$1
  test -n "$2" -a -d "$2" || error "Not a dir: '$2'" 1
  echo "$2/$1"
}

# Return path to new file in temp. dir. with ${base}- as filename prefix,
# .out suffix and subcmd with uuid as middle part.
# setup-tmp [ext [unid [(RAM_)TMPDIR]]]
setup_tmpf()
{
  test -n "$1" || set -- .out "$2" "$3"
  test -n "$2" || set -- $1 $(uuidgen) "$3"
  test -n "$1" -a -n "$2" || error "empty arg(s)" 1
  test -z "$4" || error "surplus arg(s) '$3'" 1

  test -n "$3" || set -- "$1" "$2" "$(setup_tmpd)"
  test -n "$3" -a -d "$3" || error "Not a dir: '$3'" 1

  test -d $(dirname $3/${base}$2$1) \
    || mkdir -p $(dirname $3/${base}$2$1)
  echo $3/${base}$2$1
}

