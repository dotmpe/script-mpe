#!/bin/bash

# Helpers for BATS project test env.


# Set env and other per-specfile init
test_env_init()
{
  test -n "$base" || return 12
  test -n "$uname" || uname=$(uname)

  test -n "$scriptpath" || scriptpath=$(pwd -P)
  test -n "$script_util" || script_util=$(pwd -P)/tools/sh

  test -n "$testpath" || testpath=$(pwd -P)/test
  #test -n "$default_lib" ||
  default_lib="os sys str std main"


  test -n "$BATS_LIB_PATH" || {
    BATS_LIB_PATH=$BATS_CWD/test:$BATS_CWD/test/helper:$BATS_TEST_DIRNAME
  }
  test -n "$BATS_LIB_EXTS" || BATS_LIB_EXTS=bash\ sh
  test -n "$BATS_LIB_DEFAULT" || BATS_LIB_DEFAULT=load


  # XXX: relative path to templates/fixtures?
  SHT_PWD="$( cd $BATS_CWD && realpath $BATS_TEST_DIRNAME )"
#SHT_PWD="$(grealpath --relative-to=$BATS_CWD $BATS_TEST_DIRNAME )"

  # Locate ztombol helpers and other stuff from github
  test -n "$VND_SRC_PREFIX" || VND_SRC_PREFIX=/srv/src-local
  test -n "$VND_GH_SRC" || VND_GH_SRC=$VND_SRC_PREFIX/github.com
  hostname_init
}

hostname_init()
{
  hostnameid="$(hostname -s | tr 'A-Z.-' 'a-z__')"
}

init()
{
  test_env_init || return

  # Detect when base is exec
  test -x $PWD/$base && {
    bin=$base
  } || {
    test -x "$(which $base)" && bin=$(which $base) || lib=$(basename $base .lib)
  }

  # Get lib-load, and optional libs/boot script/helper

  test -n "$2" && init_sh_boot="$2"
  test "$1" = "0" || { test -n "$init_sh_boot" || init_sh_boot="null"; }

# XXX scriptpath
  scriptpath=$PWD/src/sh/lib SCRIPTPATH=$PWD/src/sh/lib:$HOME/bin
  init_sh_libs="$1" . $script_util/init.sh
  #__load_mode=load-ext . $scriptpath/tools/sh/init.sh
  # __load_mode=load-ext . $scriptpath/util.sh

  test "$1" = "0" || {
    lib_load $default_lib
  }

  test "$2" = "0" || {
    load extra
    load stdtest
    #load assert # XXX: conflicts, load overrides 'fail'
  }

  test "$3" = "0" || {
    lib_load shell
    shell_init
  }

  #export ENV=./tools/sh/env.sh
  export ENV_NAME=testing
}


### Helpers for conditional tests

# TODO: SCRIPT-MPE-2 deprecate in favor of require-env from projectenv.lib
# Returns successful if given key is not marked as skipped in the env
# Specifically return 1 for not-skipped, unless $1_SKIP evaluates to non-empty.
is_skipped()
{
  local skipped="$(echo $(eval echo \$$(get_key "$1")_SKIP))"
  test -n "$skipped" && return
  return 1
}

# XXX: SCRIPT-MPE-2 Hardcorded list of test envs, for use as is-skipped key
current_test_env()
{
  test -n "$TEST_ENV" \
    && echo $TEST_ENV \
    || case $hostnameid in
      simza | boreas | vs1 | dandy | precise64 ) hostname -s | tr 'A-Z' 'a-z';;
      * ) whoami ;;
    esac
}

# Check if test is skipped. Currently works based on hostname and above values.
check_skipped_envs()
{
  test -n "$1" || return 1
  local skipped=0
  test -n "$1" || set -- "$(hostname -s | tr 'A-Z_.-' 'a-z___')" "$(whoami)"
  cur_env=$(current_test_env)
  for env in $@
  do
    is_skipped $env && {
        test "$cur_env" = "$env" && {
            skipped=1
        }
    } || continue
  done
  return $skipped
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
  : "${BATS_LIB_PATH_DEFAULTS:="helper node_modules vendor"}"

  # Basher has a GitHub <user>/<package> checkout tree
  : "${BASHER_PACKAGES:=$HOME/.basher/cellar/packages}"
  test ! -d $BASHER_PACKAGES ||
    BATS_LIB_PATH_DEFAULTS="$BATS_LIB_PATH_DEFAULTS $BASHER_PACKAGES"

  test -e /src/ &&
    : "${VND_SRC_PREFIX:="/src"}" ||
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

test -n "$BATS_LIB_PATH" || bats_dynamic_include_path

test -n "$BATS_LIB_EXTS" || BATS_LIB_EXTS=.bash\ .sh
test -n "$BATS_VAR_EXTS" || BATS_VAR_EXTS=.txt\ .tab
test -n "$BATS_LIB_DEFAULT" || BATS_LIB_DEFAULT=load

load() # ( PATH | NAME )
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
     


