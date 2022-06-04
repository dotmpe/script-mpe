#!/bin/sh

## Htd:Sys: dealing with vars, functions, env.

sys_htd_lib_load()
{
  export _14MB=14680064
  export _6MB=7397376
  export _5k=5120

  #test -n "$MIN_SIZE" || MIN_SIZE=1
  test -n "${MIN_SIZE-}" || MIN_SIZE=$_6MB

  test -n "${os-}" || os="$(uname -s | tr '[:upper:]' '[:lower:]')"
  test -n "${username-}" || username="$(whoami | tr -dc 'A-Za-z0-9_-')"
  test -n "${arch-}" || arch="$(uname -p)"
  test -n "${mach-}" || mach="$(uname -m)"
}

sys_htd_lib_init()
{
  test "${sys_htd_lib_init-}" = "0" && return

  test -n "${INIT_LOG-}" || return 102

  lib_assert sys os str main match || {
    $INIT_LOG error "" "In sys.lib init" $0"" 1
    return 100
  }

  test -n "${SCR_SYS_SH-}" ||  {
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
    TMPDIR=/tmp
    $INIT_LOG info "$scriptname" "TMPDIR=$TMPDIR (should be in shell profile)" >&2
  }

  $INIT_LOG info "" "Loaded sys.lib" "$0"
}

require_fs_casematch()
{
  local CWD="$PWD"
  test -n "$1" && {
    cd "$1"
  }
  test -e ".fs-casematch" || {
    test -e ".fs-nocasematch" && {
      $LOG warn "$scriptname" "Case-insensitive fs '$1' detected!" >&2
    } || {

      echo 'ok' > abc
      echo 'notok' > ABC
      test "$(echo $( cat abc ABC))" = "ok notok" && {
        $LOG debug "$scriptname" "Case-sensitive fs '$1' OK" >&2
        rm abc ABC || true
        touch .fs-casematch
      } || {
        test "$(echo $( cat abc ABC))" = "notok notok" && {
          rm abc || true
          $LOG warn "$scriptname" "Case-insensitive fs '$1' detected!" >&2
          touch .fs-nocasematch
        } || {
          rm abc ABC || true
          cd "$CWD"
          $LOG error "$scriptname" "Unknown error" 1 >&2
        }
      }
    }
  }
  cd "$CWD"
}

# require vars to be initialized, regardless of value
req_vars()
{
  while test $# -gt 0
  do
    sh_isset "$1" || { $LOG error "" "Missing variable" "$1"; return 1; }
    shift
  done
}

create_ram_disk()
{
  test -n "$1" || error "Name expected" 1
  test -n "$2" || error "Size expected" 1
  test -z "$3" || error "Surplus arguments '$3'" 1

  case "$uname" in

    darwin )
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

# If any of VALUES it not in variable LIST, add it
assert_list() # LIST VALUES...
{
	local to_add= list=$1 items="$(eval echo "\$$1")"
	shift 1
	to_add="$( for value in $@;
		do
			fnmatch "* $value *" " $items " && continue;
			echo $value;
		done )"
	eval $list="$(echo $items $to_add)"
}

# If ITEM is in items of LIST, add VALUES not already in list
expand_item() # LIST ITEM VALUES...
{
	local to_add= list=$1 item=$2 items="$(eval echo "\$$1")"
	shift 2
	fnmatch "* $item *" " $items " && {
		assert_list $list "$@"
	} || true
}

pretty_print_var()
{
  sh_isset kvsep || kvsep='='
  pretty_var="$(printf -- "$1" | tr -s '_' '-')"
  falseish "$2" && {
    printf "!$pretty_var\n"
  } || {
    trueish "$2" && {
      printf "$pretty_var\n"
    } || {
      value="$(printf -- "$2" | sed 's/\ /\\ /g')"
      printf "$pretty_var$kvsep$value\n"
    }
  }
}

print_var()
{
  case "$2" in
    *'"'*|*" "*|*"'"* )
      printf -- '%s\n' "$1=\"$2\"" ;;
    * )
      printf -- '%s\n' "$1=$2" ;;
  esac
}

min()
{
  p= s= act=echo foreach_do "$@" | sort -r | tail -n 1
}

max()
{
  p= s= act=echo foreach_do "$@" | sort | tail -n 1
}

calc() { echo "$*" | bc; }
hex2dec() { awk 'BEGIN { printf "%d\n",0x$1}'; }
dec2hex() { awk 'BEGIN { printf "%x\n",$1}'; }
mktar() { tar czf "${1%%/}.tar.gz" "${1%%/}/"; }
mkmine() { sudo chown -R ${USER} ${1:-.}; }
sendkey () {
  if [ $# -ne 0 ]; then
    echo '#' $*
    ssh $* 'cat >> ~/.ssh/authorized_keys' < ~/.ssh/id_dsa.pub
  fi
}

pwd_p()
{
  test -n "${PWD_P-}"
}

pwd_init()
{
  pwd_p || PWD_P=$PWD
}

push_pwd() # [Dir]
{
  test -z "${1-}" || { cd $1 || return; }
  case "$PWD_P" in *":$PWD" ) return ;; esac
  PWD_P=${PWD_P}:$PWD
}

pop_pwd()
{
  test -n "${PWD_P-}" || return 0
  PWD_P="${PWD_P%:*}"
  local pwd="${PWD_P//*:}"
  #local pwd="$(echo "$PWD_P" | cut -d':' -f1)"
  #PWD_P="$(echo "$PWD_P" | cut -d':' -f2- --output-delimiter=':')"
  test -n "$PWD_P" || unset PWD_P
  cd "$pwd"
}

sys_running () # ~ <Exec>
{
  pgrep "$1" >/dev/null
}

# Sync: U-S:src/sh/lib/sys.lib.sh
