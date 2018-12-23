#!/bin/sh

# FIXME: see util.sh lib-util-init replacement +script-mpe
#. "$script_util/parts/env-init-log.sh"
#. "$script_util/parts/env-ucache.sh"


#. "$script_util/parts/env-scriptpath.sh"


. $HOME/bin/tools/sh/box.env.sh &&
. $HOME/bin/box.lib.sh &&
box_run_sh_test

test -n "$U_S" || export U_S=/srv/project-local/user-scripts
#test -n "$LOG" -a -x "$LOG" || export LOG=$U_S/tools/sh/log.sh


#lib_load htd meta box doc
#lib_load std-htd htd meta box doc table disk darwin remote



$INIT_LOG "debug" "user-env" "Script-Path:" "$SCRIPTPATH"

# Id: scripts-mpe/0.0.4-dev tools/sh/user-env.sh
