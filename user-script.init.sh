#!/usr/bin/env bash

: "${us_stat:=exit}"
[[ ${user_script_uc_env-} ]] ||
  . "${US_BIN:?}"/user-script.uc.sh || ${us_stat:-exit} $?

[[ ${0##*/} == user-script.*sh ]] ||
uc_script_load user-script
