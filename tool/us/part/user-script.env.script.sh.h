#!/usr/bin/env bash
#
# This holds the static definition for user-script env (re)init script.
#
# Copyright 2018-2026 B. van Berkum <dev@dotmpe.com>
#
# Distributed under terms of the MIT license.
#
#ifndef USER_SCRIPT_ENV_SCRIPT_SH_H
#define USER_SCRIPT_ENV_SCRIPT_SH_H
#:include user-script.env.verbosity.sh.h
#:include user-script.env.standard.sh.h
: "${us_stat:=exit}"
user_script_uc_env=1
# : "${us_stat:=return}"
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
#:include user-script.env.load.sh.h

us_part --hooks:update us-term
PS4='\[\033[0m\]${BASH_SOURCE:+\[\033[34m\]$BASH_SOURCE\[\033[36m\]:\[\033[32m\]${LINENO}} \[\033[33m\]+\[\033[0m\] '

append_lookup \\
  "${UCONF:?}"/script \\
  "${UCONF:?}"/script/context \\
  "${UCONF:?}"/tool/*/exec \\
  "${U_C:?}"/script \\
  "${U_C:?}"/script/context \\
  "${U_C:?}"/tool/*/exec \\
  "${US_BIN:?}" \\
  "${US_BIN:?}"/commands \\
  "${US_BIN:?}"/contexts \\
  "${US_BIN:?}"/tool/*/exec \\
  "${U_S:?}"/tool/*/exec \\
  "${U_S:?}"/src/{,ba}sh/lib \\
  "${HTDOCS:?}"/tool/{,ba}sh/lib \\
  PATH &&

: "${US_SCR_EXT:=.us.group.bash .group.bash .bash .sh}"

# XXX: thinking about clear consistent install paths [Wed 26'03]
: "${UC_HOST_ETC:=/etc/uc}"
: "${UC_CACHE_DIR:=/var/lib/uc}"
: "${UC_USER_ETC:=/etc/uc/user}"
: "${UC_USER_LIB:=/usr/share/uc}"

# Current new target setup for SD [Wed 26'03]
: "${STATUSDIR_CACHE:=/var/cache/statusdir}"
: "${STATUSDIR_LOCAL:=/var/local/statusdir}"
: "${STATUSDIR_LOG:=/var/log/statusdir}"
: "${STATUSDIR_SHARE:=/usr/share/statusdir}"

export LOG=${LOG:-${U_S:?}/tool/sh/log.sh}

. "${U_S}/tool/sh/part/sh-mode.sh"

[[ ${uc_fun_profile-} ]] ||
#  . "${UCONF:?}/etc/profile.d/uc_fun.sh" || ${us_stat:-exit} $?
  . "${UCONF:?}/etc/shell/profile.d/180userscript_uc_funset.sh" || ${us_stat:-exit} $?

user_script_uc_env=0

[[ ${0##*/} == user-script.*sh ]] || uc_script_load user-script

# Id: user-script.env.script.sh.h                vim:set ft=bash sw=2 sts=2 et:
#endif
