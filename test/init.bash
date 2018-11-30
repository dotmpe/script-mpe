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

  test -n "$BATS_LIB_PATH" || BATS_LIB_PATH=$testpath:$testpath/helper

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

# XXX: temporary override for Bats load

load() # ( PATH | NAME )
{
  while test $# -gt 0 
  do
    load_helper "$1" || return $?
    shift
  done
}

test -n "$BATS_LIB_PATH" || {
  BATS_LIB_PATH=$BATS_CWD:$BATS_TEST_DIRNAME:$BATS_TEST_DIRNAME/helper
}

test -n "$BATS_LIB_EXTS" || BATS_LIB_EXTS=bash\ sh
test -n "$BATS_LIB_DEFAULT" || BATS_LIB_DEFAULT=load

load_helper()
{
  test -e "$1" && {
    . "$1"
    return $?
  }
  for i in ${BATS_LIB_PATH//:/ }
  do
    test -d "$i/$1" && {

      for e in $BATS_LIB_EXTS
      do
        test -e "$i/$1/$BATS_LIB_DEFAULT.$e" && {
          . "$i/$1/$BATS_LIB_DEFAULT.$e"
          return $?
        }
      done

    } || {

      test -e "$i/$1" && {
        . "$i/$1"
        return $?
      }
      for e in $BATS_LIB_EXTS
      do
        test -e "$i/$1.$e" && {
          . "$i/$1.$e"
          return $?
        }
      done
    }
  done
  return 1
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
