#!/bin/sh

test -n "${CWD-}" || CWD=$PWD
test -n "${script_util-}" || script_util=$CWD/tools/sh

for env_d in ${INIT_ENV-}
do
  test -e $script_util/parts/env-$env_d.sh && {
    . $script_util/parts/env-$env_d.sh || return 121
  } || {
      test -d "${U_S-}" || {
        $LOG error "" "Cannot find include" $env_d; return 1; }
    . $U_S/tools/sh/parts/env-$env_d.sh || return 121
  }
done
unset env_d

test -n "${INIT_LOG-}" || INIT_LOG=$script_util/log.sh

scriptname=$scriptname \
  $INIT_LOG "info" "" "Env initialized from parts" "${INIT_ENV-}"

test -n "${sh_tools-}" || sh_tools="$CWD/tools/sh"
# XXX: cleanup
  #: "${sh_tools:="$scriptpath/tools/sh"}"
  #: "${ci_tools:="$scriptpath/tools/ci"}"
util_mode=ext . $CWD/tools/sh/init-wrapper.sh || return
#. $scriptpath/tools/sh/init.sh || return
#scriptpath=$U_S/src/sh/lib . $U_S/tools/sh/init.sh || return

lib_lib_load && lib_lib_init || return

test -n "${INIT_LIB-}" && {
  eval INIT_LIB=\"$INIT_LIB\" || return 122
} || {
  INIT_LIB="$default_lib" # From lib.lib.sh init
}

scriptname=$scriptname \
  $INIT_LOG note "" "Bootstrapping..." "$INIT_LIB"
lib_load $INIT_LIB || return
lib_init $INIT_LIB || return

$INIT_LOG debug "" "Init for 'main' finished"
unset INIT_LOG
#
