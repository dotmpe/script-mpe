#!/usr/bin/env make.sh

# Statusdir - a property store for bash with lightweight backends

# Does not store actual properties yet, and the tree files are not actually used.
# The files in the index are used to store lists of keys, see env.sh

set -eu

version=0.0.4-dev # script-mpe


# Subcommands

statusdir__info()
{
  export verbosity=4
  "$0" version
  note "Root:"
  "$0" root
  note "Backends:"
  "$0" backends
  note "List:"
  "$0" list
}


statusdir_man_1__root='Echo statusdir store location'
statusdir__root()
{
  test -n "$STATUSDIR_ROOT" || return 14
  echo "$STATUSDIR_ROOT"
}
statusdir_flags__root=-


statusdir_man_1__backends='List backends available and online'
statusdir__backends()
{
  local bn sd_be sd_be_h
  for bn in $scriptpath/statusdir-*.sh
  do
    sd_be=$(basename $bn .lib.sh | cut -d '-' -f 2)
    . $bn
    sd_be_h=sd_${sd_be}
    $sd_be_h ping && note "$sd_be found" || warn "No $sd_be backend"
  done
}
statusdir_flags__backends=-
statusdir_als__bes=backends


statusdir_man_1__backend="Print current backend's name. See 'be' to invoke it
directly. "
statusdir__backend()
{
  statusdir_run backend
}

statusdir_man_1__assert="echos path. Default index is 'tree'."
statusdir_spc__assert="assert <rtype> [<index-name-id>]"
statusdir__assert()
{
  statusdir_assert "$@"
}

# As statusdir__assert, but last arg is filename
# (does not touch file, but echos it)
statusdir__assert_dir()
{
  test -n "${STATUSDIR_ROOT-}" || return 64
  local tree path
  tree="$(echo "$@" | tr ' ' '/')"
  path=$STATUSDIR_ROOT$tree
  test -d $path || mkdir -vp $(dirname $path)
  echo $path
}

statusdir__record()
{
  statusdir_record "$@"
}

statusdir__run ()
{
  statusdir_run "$@"
}

statusdir__stat ()
{
  statusdir_run stat "$@"
}

statusdir__status ()
{
  statusdir_run status "$@"
}

statusdir__index()
{
  : "${fsd_rtype:="index"}"
  statusdir_run index "$@"
}

statusdir__index_file() # [ Name | Path ]
{
  test -n "$*" || set -- "name"
  statusdir_run $1 "$@"
}

# TODO: deprecate for index/index-file
statusdir__file()
{
  test -n "$STATUSDIR_ROOT" || return 66
  tree="$(echo "$@" | tr ' ' '/')"
  trueish "${assert_dir-}" && case "$tree" in */* ) ;;
        * ) statusdir__assert_dir "$@" >/dev/null ;;
      esac
  echo $STATUSDIR_ROOT"index/$tree"
}

# Create and cat properties file ($format $1)
statusdir__properties()
{
  (
    props=$(statusdir__file "$1.properties")
    # XXX: initialize file sd_be=properties
    #statusdir.sh assert-

    test -n "$format" || format=properties
    case "$format" in
      properties )
          cat $props
        ;;
      sh )
          read_nix_style_file $props | properties2sh -
        ;;
    esac
  )
}



# XXX

# XXX: get some plumping commands to deal with embedded structures
# at paths.

# Assert given value exists at path in state.json
# arg: 1:jspath 2:value
statusdir__assert_json()
{
  # FIXME assert-json
  sf=$(statusdir__file "state.json" || return $?)
  test -s "$sf" || echo '{}' >$sf
  test -n "$1" || { echo $sf; return; }
  echo "$@" | tr ' ' '\n' | jsotk.py update $sf.tmp $sf || {
    echo "statusdir assert-json: Error reading $sf. " 1>&2
    return 1
  }
  test -s "$sf.tmp" && mv $sf.tmp $sf || {
    test -s "$sf" && {
      echo "statusdir assert-json: Error updating $sf with '$@'. " 1>&2
    }
  }
}

# Merge another json into state.json
# arg: 1:filepath 2:root-jspath
statusdir__cons_json()
{
  local status_json="$(statusdir__assert_json)" tmpf=$(setup_tmpf .json)
  jsotk.py merge $tmpf $status_json $1 || {
    rm $tmpf
    return 1
  }
  mv $tmpf $status_json
  echo $status_json
}
statusdir_flags__cons_json=-

statusdir__ping()
{
  test -z "$*" || error "unexpected arguments '$*'" 1
  $sd_be_h ping || return $?
}

statusdir__init()
{
  $sd_be_h init "$@" || return $?
}

statusdir__deinit()
{
  $sd_be_h deinit "$@" || return $?
}

statusdir__list()
{
  test -n "${1-}" || error "key expected" 1
  test $# -eq 1 -a -z "${2-}" || error "surplus arguments '$2'" 1
  $sd_be_h list $1 || return $?
}

statusdir__get()
{
  test -n "${1-}" || error "key expected" 1
  test $# -eq 1 -a -z "${2-}" || error "surplus arguments '$2'" 1
  $sd_be_h get $1 || return $?
}

statusdir__set()
{
  test -n "${1-}" || error "key expected" 1
  test -n "${2-}" || error "value expected" 1
  test -n "${3-}" || set -- "$1" "$2" 0
  test $# -eq 3 -a -z "${4-}" || error "surplus arguments '$4'" 1
  $sd_be_h set "$1" "$3" "$2" || return $?
}

# FIXME: statusdir_als__delete=del
statusdir__del()
{
  test -n "${1-}" || error "key expected" 1
  test $# -eq 1 -a -z "${2-}" || error "surplus arguments '$2'" 1
  $sd_be_h del $1 || return $?
}

statusdir__incr()
{
  test -n "${1-}" || error "key expected" 1
  test -n "${2-}" || set -- "$1" 1
  test $# -eq 2 -a -z "${3-}" || error "surplus arguments '$3'" 1
  $sd_be_h incr $1 $2 || return $?
}

statusdir__decr()
{
  test -n "${1-}" || error "key expected" 1
  test -n "${2-}" || set -- "$1" 1
  test $# -eq 2 -a -z "${3-}" || error "surplus arguments '$3'" 1
  $sd_be_h decr "$@" || return $?
}

statusdir__exists()
{
  test -n "${1-}" || error "key expected" 1
  test $# -eq 1 -a -z "${2-}" || error "surplus arguments '$2'" 1
  $sd_be_h exists "$1" || return $?
}

statusdir__has()
{
  $sd_be_h has "$@" || return $?
}

statusdir__members()
{
  test -n "${1-}" || error "key expected" 1
  test $# -eq 1 -a -z "${2-}" || error "surplus arguments '$2'" 1
  $sd_be_h members "$1" || return $?
}

statusdir__add()
{
  test -n "${1-}" || error "key expected" 1
  test -n "${2-}" || error "member expected" 1
  test $# -eq 2 -a -z "${3-}" || error "surplus arguments '$3'" 1
  $sd_be_h add "$@" || return $?
}

statusdir__rem()
{
  test -n "${1-}" || error "key expected" 1
  test -n "${2-}" || error "member expected" 1
  test $# -eq 2 -a -z "${3-}" || error "surplus arguments '$3'" 1
  $sd_be_h rem "$@" || return $?
}


statusdir__be()
{
  test -n "${1-}" || error "cmd expected" 1
  $sd_be_h "$@"
}

statusdir__x()
{
  test -n "${1-}" || error "cmd expected" 1
  $sd_be_h x "$@"
}


# Generic subcmd's


statusdir_als____version=version
statusdir_als___V=version
statusdir_grp__version=ctx-main\ ctx-std

statusdir_als____help=help
statusdir_als___h=help
statusdir_grp__help=ctx-main\ ctx-std


statusdir_man_1__edit='Edit this script and files'
statusdir_spc__edit='-e|edit [FILES]'
statusdir__edit()
{
  $EDITOR $0 $(which $base.sh) "$@"
}
statusdir_als___e=edit



statusdir_main_usage()
{
    cat <<EOM
statusdir.sh - Wrapper for simple access to memory store and DB services.

Usage:
    statusdir <cmd> [<args>..]

EOM
}



# Script main functions

main-bases statusdir sd main std
main-local sd_be_h
main-init-env \
  INIT_ENV="init-log strict 0 0-src 0-u_s dev ucache scriptpath std" \\
  INIT_LIB="\$default_lib date statusdir notify log logger-std logger-theme main meta shell str-htd std stdio ctx-std ctx-statusdir ctx-class"

#main-init \
  #test -n "${verbosity-}" || verbosity=${v:-5}
  #export verbosity

main-load \
    test -n "$flags" || flags=b

#  statusdir_lib_start && statusdir_start
main-load-flags \
    - ) ;; \
    b ) statusdir_start || return ;; \
    * ) stderr error "No such flag (sub-command $subcmd): load $x" 1 ;;

main-unload-flags \
    - ) ;; \
    b ) statusdir_finish ;; \
    * ) stderr error "No such flag (sub-command $subcmd): unload $x" 1 ;;

#
