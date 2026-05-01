#!/usr/bin/env bash
: "${DEBUG:=0}"
: "${QUIET:=0}"
((QUIET)) && VERBOSE=0 || : "${VERBOSE:=0}"
: "${ASSERT:=0}"
: "${DEV:=0}"
: "${DIAG:=0}"
: "${INIT:=0}"
! { ((DEBUG)) || ((DIAG)) || ((DEV)) || ((INIT)); } ||
{
  # This works in Bash, so...
  0 () {
    ((QUIET)) ||
    >&2 echo "Invalid invocation of '0' as command! At $(caller)"
    false
  }
  1 () {
    ((QUIET)) ||
    >&2 echo "Invalid invocation of '1' as command! At $(caller)"
    true
  }
}
: "${us_stat:=exit}"
user_script_uc_env=1
[[ ${PS1-} ]] &&
  set -uo pipefail ||
  set -euo pipefail
shopt -s extglob
! ((QUIET)) ||
! ((DEBUG)) ||
{
  >&2 echo "Starting $0: user-script script env for ${*@Q}"
  >&2 trap
}
[[ ${US_ENV_PARTS:+set} ]] &&
[[ ${US_ENV_INIT:+set} ]] &&
. <(echo "$US_ENV_INIT") || {
  >&2 echo "E$?: Expected User-Script env; definitions missing or source failure"
  exit 121
}

us_part --hooks:update us-term
PS4='\[\033[0m\]${BASH_SOURCE:+\[\033[34m\]$BASH_SOURCE\[\033[36m\]:\[\033[32m\]${LINENO}} \[\033[33m\]+\[\033[0m\] '

append_lookup \
  "${UCONF:?}"/script \
  "${UCONF:?}"/script/context \
  "${UCONF:?}"/tool/*/exec \
  "${U_C:?}"/script \
  "${U_C:?}"/script/context \
  "${U_C:?}"/tool/*/exec \
  "${US_BIN:?}" \
  "${US_BIN:?}"/commands \
  "${US_BIN:?}"/contexts \
  "${US_BIN:?}"/tool/*/exec \
  "${U_S:?}"/tool/*/exec \
  "${U_S:?}"/src/{,ba}sh/lib \
  "${HTDOCS:?}"/tool/{,ba}sh/lib \
  PATH &&

: "${US_SCR_EXT:=.us.group.bash .group.bash .bash .sh}"

: "${UC_HOST_ETC:=/etc/uc}"
: "${UC_CACHE_DIR:=/var/lib/uc}"
: "${UC_USER_ETC:=/etc/uc/user}"
: "${UC_USER_LIB:=/usr/share/uc}"

: "${STATUSDIR_CACHE:=/var/cache/statusdir}"
: "${STATUSDIR_LOCAL:=/var/local/statusdir}"
: "${STATUSDIR_LOG:=/var/log/statusdir}"
: "${STATUSDIR_SHARE:=/usr/share/statusdir}"

export LOG=${LOG:-${U_S:?}/tool/sh/log.sh}

. "${U_S}/tool/sh/part/sh-mode.sh"

[[ ${uc_fun_profile-} ]] ||
  . "${UCONF:?}/etc/shell/profile.d/180userscript_uc_funset.sh" || ${us_stat:-exit} $?

user_script_uc_env=0

[[ ${0##*/} == user-script.*sh ]] || uc_script_load user-script

