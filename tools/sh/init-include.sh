#!/usr/bin/env bash

# Initialize for ``sh-include PART..``

true "${U_S:="/srv/project-local/user-scripts"}"
true "${sh_tools:="$U_S/tools/sh"}"

test -d $U_S/tools/sh/parts/include.sh || {
    tree $U_S
    sleep 2
    sync
    exit 1
}
. "$sh_tools/parts/fnmatch.sh"
. "$U_S/tools/sh/parts/include.sh"
. "$U_S/tools/ci/parts/print-err.sh"

# Sync: U-s
