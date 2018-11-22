#!/bin/sh

environment_lib_load()
{
  true
}

environment_init() # [ FILE or CMDLINE ] | ENV_NAME=dev ENV_VER=dev ENV_CWD=
{
  test -e "$1" && {
    . "$1" || return
  } || {
    test -z "$1" || {
      eval $(echo "$1" | tr 'A-Z' 'a-z')
    }
  }
}

environment_defaults()
{
  test -n "$env_ver" || env_ver=master
  test -n "$env_name" || env_name=$env_ver
  test -n "$env_cwd" || env_cwd=.
}

environment_env()
{
  environment_init "$@" || return
  environment_defaults
  env="environment_version=$env_ver environment_name=$env_name environment_cwd=$env_cwd"
}
