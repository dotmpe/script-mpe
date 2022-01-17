#!/usr/bin/env bash

# Helpers for BATS project test env.


# Return level number as string for use with line-type or logger level, channel
log_level_name() # Level-Num
{
  case "$1" in
      1 ) echo emerg ;;
      2 ) echo crit ;;
      3 ) echo error ;;
      4 ) echo warn ;;
      5 ) echo note ;;
      6 ) echo info ;;
      7 ) echo debug ;;

      2.5 ) echo bail ;;
      3.3 ) echo err ;;
      4.2 ) echo fail ;;
      5.1 ) echo ok ;;
      6.4 ) echo skip ;;
      7.6 ) echo diag ;;

      * ) return 1 ;;
  esac
}

log_level_num() # Level-Name
{
  case "$1" in
      emerg ) echo 1 ;;
      crit  | bail ) echo 2 ;;
      error | err ) echo 3 ;;
      warn  | fail ) echo 4 ;;
      note  | notice | ok ) echo 5 ;;
      info  | skip | TODO ) echo 6 ;;
      debug | diag ) echo 7 ;;

      * ) return 1 ;;
  esac
}


assert_equal()
{
  test $# -eq 2 || return
  local actual="$1" expected="$2"
  test "$actual" = "$expected" &&
    $LOG "debug" "OK" "Matches:" "$expected" ||
    $LOG "warn" "Not OK" "Failed:" "'$actual' != '$expected'" 1
}

diag() { echo "$@"; }


# Simple init-log shell function that behaves well in unintialzed env,
# but does not add (vars) to env.
err_() # [type] [cat] [msg] [tags] [status]
{
  test $# -gt 0 || return
  test $# -gt 1 || set -- "$@" "" "" "" ""
  test -z "${verbosity:-}" -a -z "${DEBUG:-}" && return
  test -n "$2" || set -- "$1" "$base" "$3" "${4:-}" "${5:-}"
  test -z "${verbosity:-}" -a -n "${DEBUG:-}" || {

    case "$1" in [0-9]* ) true ;; * ) false ;; esac && {
      lvl=$(log_level_name "$1")
    } || {
      lvl=$(log_level_num "$1")
    }

    test $verbosity -ge ${lvl:-0} || {
      test -n "${5:-}" && exit $5 || {
        return 0
      }
    }
  }

  printf -- "%s\n" "[$2] $1: $3 <$4> (${5:-})" >&2
  test -z "${5:-}" || exit $5 # NOTE: also exit on '0'
}

# Set env and other per-specfile init
test_env_load()
{
  test -n "$sh_tools" || return 103 # NOTE: sanity
  test -n "${DEBUG-}" || DEBUG=
  test -n "${INIT_LOG-}" || INIT_LOG=err_

  . ~/.local/etc/profile.d/_local.sh

  true "${U_S:="/srv/project-local/user-scripts"}"
  . "$sh_tools/parts/fnmatch.sh"
  . "$U_S/tools/sh/parts/include.sh"
  . "$U_S/tools/ci/parts/print-err.sh"

  . "$U_S/contexts/ctx-ctx.lib.sh" &&
  ctx_lib_load

  test -n "${SCRIPTPATH:-}" || {
    SCRIPTPATH=
    sh_include \
        print-err unique-paths remove-dupes \
        env-scriptpath-deps
    export SCRIPTPATH=$HOME/bin:$SCRIPTPATH
  }

  sh_include env-strict
  #sh_include debug-exit
  sh_include env-log-reinit
  sh_include env-0
  #sh_include env-ci
  sh_include env-dev
  sh_include env-ucache
  #sh_include std-ci-helper
  sh_include env-0-u_s
  sh_include env-docker-hub
  sh_include env-test
  sh_include env-test-bats
  #sh_include env-scriptpath-deps
  sh_include env-info

  # XXX: need to adjust if build.txt column order changes
  # Get env init ('0' prefixed) Test suite steps from build.txt
  for env_d in $( grep -vE '^\s*(#.*|\s*)$' build.txt|awk '{print $6" "$1}'|grep '^0'|sort -u|cut -f2 -d' ')
  do
    $INIT_LOG "debug" "" "Loading env-part" "$env_d"
    #echo sh_include $env_d >&2
    #sh_include $env_d
    #part=$ci_tools/parts/$env_d.sh
    #test -e "$part" || part=$sh_tools/parts/$env_d.sh
    #. "$part" ||
    #    $INIT_LOG "warn" "" "Failed env-part"  "$? $env_d"
  done
  unset part env_d

  test -n "$base" || return 12 # NOTE: sanity
  test -n "$INIT_LOG" || return 109 # NOTE: sanity
  $INIT_LOG "info" "" "Env initialized from parts"
}

# Set env and other per-specfile init
test_env_init()
{
  set -euo pipefail

  test "${TEST_ENV:-"test"}" = "test" &&
      export scriptname=test:$base ||
      export scriptname=$TEST_ENV:test:$base

  # For bats internals
  test_number_in_suite=

  #test -n "$scriptname" && {
  #  test -z "$scriptname_d" && {
  #    scriptname_d="$scriptname test:$TEST_ENV"
  #  } || {
  #    fnmatch "$scriptname *" "$scriptname_d" ||
  #      scriptname_d="$scriptname test:$TEST_ENV"
  #  }
  #  scriptname=$scriptname:test:$base

  # Detect when base is exec
  test -x $PWD/$base && {
    bin=$base
  } || {
    test -x "$(which $base)" && bin=$(which $base) || lib=$(basename -- "$base" .lib)
  }
}


# Bootstrap test-env for Bats ~ 1:Init 2:Load-Libs 3:Boot-Std 4:Boot-Script
init() # ( 0 | 1 [~ [~ [~]]] )
{
  test -z "$lib_loaded" || return 105

  test -n "$CWD" || CWD=$(pwd -P)
  test -n "$sh_tools" || sh_tools=$CWD/tools/sh
  script_util=$sh_tools
  test -n "$ci_tools" || ci_tools=$CWD/tools/ci
  test -d "$sh_tools" || return 103 # NOTE: sanity

  # Get lib-load, and optional libs/boot script/helper
  while test $# -lt 4 ; do set -- "$@" "" ; done
  test -n "$1" || set -- "1" "$2" "$3" "$4"
  test -n "$2" || set -- "$1" "$1" "$3" "$4"
  test -n "$3" || set -- "$1" "$2" "$2" "$4"
  test -n "$4" || set -- "$1" "$2" "$3" "$3"

  # Set scriptname, bin and base vars for testsuite
  test_env_init || return

  # Setup new Bats load() helper and include path
  load_init_bats
  load() { load_override "$@"; }

  test "$1" = "0" && return

  # Load tools/*/parts bits
  test_env_load || return

  # Set variables for init.sh script
  init_sh_libs="$2"
  init_sh_boot="$3"

  test "$2" != "1" -o \( -n "$3" -a "$3" != "0" \) || init_sh_boot="null"

  test "$init_sh_boot" = "1" && {
    test "$3" = "0" || init_sh_boot='std test'
    test "$4" = "0" || init_sh_boot=$init_sh_boot' script'
  }

  . $U_S/tools/sh/init.sh
# XXX: use dep U-S . $u_s_util/init.sh
}


# Non-bats bootstrap to initialize access to test-helper libs with 'load'
load_init() # [ 0 ]
{
  test "${1-}" = "0" || {
    test_env_init || return
  }

  test -n "$TMPDIR" || TMPDIR=/tmp
  . "./tools/sh/parts/env-test-bats.sh"
  load_init_bats
#  test "$PWD" = "$scriptpath"
}


# XXX: temporary override for Bats load
load_old() {
  local name="$1"
  local filename

  if [[ "${name:0:1}" == '/' ]]; then
    filename="${name}"
  else
    filename="$BATS_TEST_DIRNAME/${name}.bash"
  fi

  if [[ ! -f "$filename" ]]; then
    printf 'bats: %s does not exist\n' "$filename" >&2
    exit 1
  fi

  source "${filename}"
}

# XXX: intial bits shouldn't they be in suite exec.
bats_autosetup_common_includes()
{
  : "${BATS_LIB_PATH_DEFAULTS:="test helper test/helper node_modules vendor"}"

  # Basher has a GitHub <user>/<package> checkout tree
  : "${BASHER_PACKAGES:=$HOME/.basher/cellar/packages}"
  test ! -d $BASHER_PACKAGES ||
    BATS_LIB_PATH_DEFAULTS="$BATS_LIB_PATH_DEFAULTS $BASHER_PACKAGES"

  test -e /src/local &&
    : "${VND_SRC_PREFIX:="/src/local"}" ||
    : "${VND_SRC_PREFIX:="$HOME/build"}"

  : "${VENDORS:="google.com github.com bitbucket.org"}"
  for vendor in $VENDORS
  do
    test -e $VND_SRC_PREFIX/$vendor || continue

    BATS_LIB_PATH_DEFAULTS="$BATS_LIB_PATH_DEFAULTS $VND_SRC_PREFIX/$vendor"
  done
}

bats_dynamic_include_path()
{
  # Require BATS_LIB_PATH_DEFAULTS, a list of partial relative and
  # absolute path names to initialze BATS_LIB_PATH with
  bats_autosetup_common_includes

  # Build up default path, start-to-end.
  BATS_LIB_PATH="$BATS_TEST_DIRNAME"

  # Add default helper or package locations, for relative paths
  # first those beside test script (BATS_TEST_DIRNAME) then BATS_CWD
  for path_default in $BATS_LIB_PATH_DEFAULTS
  do
    test "${path_default:0:1}" = '/' && {
      test -e "$path_default"  || continue

      BATS_LIB_PATH="$BATS_LIB_PATH:$path_default"
    } || {

      for bats_path in "$BATS_TEST_DIRNAME" "$BATS_CWD"
      do
        test -d "$bats_path/$path_default" || continue
        BATS_LIB_PATH="$BATS_LIB_PATH:$bats_path/$path_default"
      done
    }
  done
}

load_init_bats()
{
  test -n "${BATS_LIB_PATH:-}" || bats_dynamic_include_path

  : "${BATS_LIB_EXTS:=".bash .sh"}"
  : "${BATS_VAR_EXTS:=".txt .tab"}"
  : ${BATS_LIB_DEFAULT:=load}
}

load_override() # ( PATH | NAME )
{
  test $# -gt 0 || return 1
  : "${lookup_exts:=${BATS_LIB_EXTS}}"
  while test $# -gt 0
  do
    source $(bats_lib_lookup "$1" || return $? ) || return $?
    shift
  done
}

bats_lib_lookup()
{
  test $# -eq 1 || return 1
  : "${lookup_exts:=${BATS_VAR_EXTS}}"
  test "${1:0:1}" = '/' -a -e "$1" && {
    echo "$1"
    return
  }
  for i in ${BATS_LIB_PATH//:/ }
  do
    test -d "$i/$1" && {

      for e in $lookup_exts
      do
        test -e "$i/$1/$BATS_LIB_DEFAULT$e" && {
          echo "$i/$1/$BATS_LIB_DEFAULT$e"
          return
        }
      done

    }
    test -f "$i/$1" && {
      echo "$i/$1"
      return
    }
    for e in $lookup_exts
    do
      test -e "$i/$1$e" && {
        echo "$i/$1$e"
        return
      }
    done
  done
  return 1
}

# Sync: U-S:
