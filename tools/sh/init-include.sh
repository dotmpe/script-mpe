#!/usr/bin/env bash

## Initialize for ``sh-include PART..``

true "${U_S:="/srv/project-local/user-scripts"}"

source "$U_S/tools/sh/parts/fnmatch.sh"
source "$U_S/tools/sh/parts/include.sh"
source "$U_S/tools/sh/parts/scriptname-d.sh"
source "$U_S/tools/ci/parts/print-err.sh"

# Sync: U-s
