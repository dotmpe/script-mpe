#!/bin/sh


env_lib_load ()
{
  test -n "${META_DIR-}" || META_DIR=.meta
}

env_lib_init ()
{
  test "${env_lib_init-}" = "0" && return # One time init
  test -n "${ENV_CACHE-}" || ENV_CACHE=$META_DIR/cache
  test -n "${ENV_LIBS-}" || ENV_LIBS=
}

# List static env files
env_list ()
{
  echo $META_DIR/cache/*-env.sh
}

env_update ()
{
  test -n "$ENV_LIBS" || return
  lib_require $ENV_LIBS || return
  lib_init $ENV_LIBS || return
  local lib_id vid
  for lib_id in $ENV_LIBS
  do mkvid $lib_id
    ${vid}_lib_env | tee $ENV_CACHE/$lib_id-lib-env.sh
  done >$ENV_CACHE/env.sh
}
