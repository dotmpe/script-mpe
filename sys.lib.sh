#!/bin/sh

# Sys: lower level Sh helpers; dealing with vars, functions, and other shell
# ideosyncracities

set -e



sys_load()
{
  test -n "$SCR_SYS_SH" ||  {
    test -n "$SHELL" &&
    SCR_SYS_SH="$(basename "$SHELL")" ||
    SCR_SYS_SH=bash
  }

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
    $scriptdir/std.lib.sh info "TMPDIR=$TMPDIR (should be in shell profile)"
  }
}


require_fs_casematch()
{
  test -n "$CWD" || CWD="$(pwd)"
  test -n "$1" && {
    cd "$1"
  }
  test -e ".fs-casematch" || {
    test -e ".fs-nocasematch" && {
      warn "Case-insensitive fs '$1' detected!"
    } || {

      echo 'ok' > abc
      echo 'notok' > ABC
      test "$(echo $( cat abc ABC))" = "ok notok" && {
        debug "Case-sensitive fs '$1' OK"
        rm abc ABC || noop
        touch .fs-casematch
      } || {
        test "$(echo $( cat abc ABC))" = "notok notok" && {
          rm abc || noop
          warn "Case-insensitive fs '$1' detected!"
          touch .fs-nocasematch
        } || {
          rm abc ABC || noop
          cd "$CWD"
          error "Unknown error" 1
        }
      }
    }
  }
  cd "$CWD"
}


incr()
{
  local incr_amount
  test -n "$2" && incr_amount=$2 || incr_amount=1
  v=$(eval echo \$$1)
  export $1=$(( $v + $incr_amount ))
}

getidx()
{
  test -n "$1" || error getidx-array 1
  test -n "$2" || error getidx-index 1
  test -z "$3" || error getidx-surplus 1
  local idx=$2
  set -- $1
  eval echo \$$idx
}

# test for var decl, io. to no override empty
var_isset()
{
  test -n "$1" || error "var-isset arg expected" 1
  # [2017-02-03] somehow Sh compatible setup broke so (testing at least) so
  #   split it up into bash, and expanded on testing. And some more testing and
  #   fiddling. Using SCR_SYS_SH=bash-sh to make some frontend exceptions.
  case "$SCR_SYS_SH" in

    bash-sh|sh )
        # Aside from declare or typeset in newer reincarnations,
        # in posix or modern Bourne mode this seems to work best:
        ( set | grep -q '\<'$1'=' ) || return 1
      ;;

    bash )
        # Bash: https://www.cyberciti.biz/faq/linux-unix-howto-check-if-bash-variable-defined-not/
        $scriptpath/tools/sh/var-isset.bash "$1" || return 1
      ;;

    * )
        error "SCR_SYS_SH='$SCR_SYS_SH'" 12
      ;;

  esac
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
  #. /dev/null # source empty file
  #echo -n # echo nothing
  #printf "" # id. if echo -n incompatible (Darwin)
  set -- # clear arguments (XXX set nothing?)
  #return # since we're in a function
}

# Error unless non-empty and true-ish
trueish()
{
  test -n "$1" || return 1
  case "$1" in
    [Oo]n|[Tt]rue|[Yyj]|[Yy]es|1)
      return 0;;
    * )
      return 1;;
  esac
}

# No error on empty or value unless matches trueish
not_trueish()
{
  test -n "$1" || return 0
  trueish "$1" && return 1 || return 0
}

# Error unless non-empty and falseish
falseish()
{
  test -n "$1" || return 1
  case "$1" in
    [Oo]ff|[Ff]alse|[Nn]|[Nn]o|0)
      return 0;;
    * )
      return 1;;
  esac
}

# Error on empty or other falseish, but not other values
not_falseish()
{
  test -n "$1" || return 1
  falseish "$1" && return 1 || return 0
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

# echo value of varname $1 on stdout if non empty
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
  test -n "$2" || set -- $1 $(get_uuid) "$3"
  test -n "$1" -a -n "$2" || error "empty arg(s)" 1
  test -z "$4" || error "surplus arg(s) '$3'" 1

  test -n "$3" || set -- "$1" "$2" "$(setup_tmpd)"
  test -n "$3" -a -d "$3" || error "Not a dir: '$3'" 1

  test -d $(dirname $3/$2$1) \
    || mkdir -p $(dirname $3/$2$1)
  echo $3/$2$1
}

# sys-confirm PROMPT ; {choice_confirm}
sys_prompt()
{
  echo $1
  read choice_confirm
}

# sys-confirm PROMPT
sys_confirm()
{
  local choice_confirm=
  sys_prompt "$1"
  trueish "$choice_confirm"
}

mkrlink()
{
  # TODO: find shortest relative path
  printf "Linking "
  ln -vs $(basename $1) $2
}

