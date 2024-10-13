#!/bin/sh

test -n "${CWD-}" || CWD=$PWD
test -n "${script_util-}" || script_util=$CWD/tool/sh

lk=":tool:sh:init"

for env_d in ${INIT_ENV-}
do
  test -e $script_util/part/env-$env_d.sh && {
    . $script_util/part/env-$env_d.sh || return 121
  } || {
      test -d "${U_S-}" || {
        $LOG error "" "Cannot find include" $env_d; return 1; }
    . $U_S/tool/sh/part/env-$env_d.sh || return 121
  }
done
unset env_d

test -n "${INIT_LOG-}" || INIT_LOG=$script_util/log.sh
command -v "$INIT_LOG" >/dev/null 2>&1 || INIT_LOG=/etc/profile.d/uc-profile.sh

scriptname=$scriptname \
  $INIT_LOG "info" "$lk" "Env initialized from parts" "${INIT_ENV-}"

test -n "${sh_tools-}" || sh_tools="$CWD/tool/sh"
# XXX: cleanup
  #: "${sh_tools:="$scriptpath/tool/sh"}"
  #: "${ci_tools:="$scriptpath/tool/ci"}"
util_mode=ext . $U_S/tool/sh/init-wrapper.sh || return
#. $scriptpath/tool/sh/init.sh || return
#scriptpath=$U_S/src/sh/lib . $U_S/tool/sh/init.sh || return

test function = "$(type -t lib_load)" || {
  lib_lib__load && lib_lib__init || return
}

test -n "${INIT_LIB-}" && {
  eval INIT_LIB=\"$INIT_LIB\" || return 122
} || {
  INIT_LIB="$default_lib" # From lib.lib.sh init
}

scriptname=$scriptname \
  $INIT_LOG note "$lk" "Bootstrapping..." "$INIT_LIB"
lib_load $INIT_LIB || return
lib_init $INIT_LIB || return

$INIT_LOG debug "$lk" "Init for 'main' finished"
unset INIT_LOG
#
