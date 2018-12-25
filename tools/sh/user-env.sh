#!/bin/sh
test -z "${sh_usr_env:-}" && sh_usr_env=1 || exit 98 # Recursion

test -z "$DEBUG" || print_yellow "" "Including sh:usr:env parts..."

test ! -e ~/.local/etc/tokens.d/docker-hub-bvberkum.sh ||
  . ~/.local/etc/tokens.d/docker-hub-bvberkum.sh

# FIXME: see util.sh lib-util-init replacement +script-mpe
. "$script_util/parts/env-dev.sh"
. "$script_util/parts/env-0.sh"

#. "$U_S/tools/sh/init.sh"
. "$script_util/init.sh"
#. "$HOME/bin/tools/sh/init.sh"

type func_exists >/dev/null 2>/dev/null || ci_abort "Missing sys.lib" 1
func_exists lib_load || ci_bail "lib.lib missing"

# XXX: cleanup
#: "${INIT_LOG:="$LOG"}"
#: "${INIT_LOG:="$U_S/tools/sh/log.sh"}"
: "${INIT_LOG:="$script_util/log.sh"}"

lib_loaded || true

. ./tools/sh/box.env.sh &&
. ./box.lib.sh &&
box_run_sh_test

#lib_load htd meta box doc
#lib_load std-htd htd meta box doc table disk darwin remote


test -z "$DEBUG" || {
  print_green "" "Finished sh:usr:env <LOG=$LOG INIT_LOG=$INIT_LOG>"
}

$INIT_LOG "debug" "user-env" "Finished. Libs:" "$lib_loaded"
$INIT_LOG "debug" "user-env" "Script-Path:" "`echo "$SCRIPTPATH"|tr ':' '\t'`"

# Id: scripts-mpe/0.0.4-dev tools/sh/user-env.sh
