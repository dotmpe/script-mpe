#!/usr/bin/env bash

[[ ${user_script_uc_env} ]] ||
  . "${US_BIN:?}"/user-script.uc.sh || ${us_stat:-exit} $?

uc_script_load user-script
