#!/bin/sh


env_lib__load ()
{
  test -n "${METADIR-}" || METADIR=.meta
}

env_lib__init ()
{
  test "${env_lib_init-}" = "0" && return # One time init
  test -n "${ENV_CACHE-}" || ENV_CACHE=$METADIR/cache
  test -n "${ENV_LIBS-}" || ENV_LIBS=
  ! sys_debug -dev -debug -init ||
    $LOG notice "" "Loaded env.lib" "$(sys_debug_tag)"
}

# List static env files
env_list ()
{
  echo $METADIR/cache/*-env.sh
}

env_update ()
{
  test -n "$ENV_LIBS" || return
  lib_require $ENV_LIBS || return
  lib_init $ENV_LIBS || return
  local lib_id vid
  for lib_id in $ENV_LIBS
  do str_vword vid "$lib_id"
    ${vid}_lib_env | tee $ENV_CACHE/$lib_id-lib-env.sh
  done >$ENV_CACHE/env.sh
}
