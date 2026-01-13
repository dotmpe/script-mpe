#!/usr/bin/env bash

user_script_uc_env=1
: "${us_stat:=return}"
[[ ${PS1-} ]] &&
  set -Tuo pipefail ||
  set -eETuo pipefail
shopt -s extglob

[[ ${US_ENV_PARTS:+set} ]] &&
[[ ${US_ENV_INIT:+set} ]] &&
eval "$US_ENV_INIT" || {
  >&2 echo "Expected User-Script env"
  exit 121
}

us_part --hooks:update us-term
PS4='\[\033[0m\]${BASH_SOURCE:+\[\033[34m\]$BASH_SOURCE\[\033[36m\]:\[\033[32m\]${LINENO}} \[\033[33m\]+\[\033[0m\] '

append_lookup \
  "${UCONF:?}/script" \
  "${U_C:?}/script" \
  "${UCONF:?}"/tool/*/exec \
  "${U_C:?}"/tool/*/exec \
  "${U_S:?}"/tool/*/exec \
  "${US_BIN:?}" \
  "${US_BIN:?}"/tool/*/exec \
  "${U_S:?}/src/sh/lib" \
  PATH &&

: "${US_SCR_EXT:=.us.group.bash .group.bash .bash .sh}"

[[ ${uc_fun_profile-} ]] ||
#  . "${UCONF:?}/etc/profile.d/uc_fun.sh" || ${us_stat:-exit} $?
  . "${UCONF:?}/etc/shell/profile.d/180userscript_uc_funset.sh" || ${us_stat:-exit} $?

user_script_uc_env=0
