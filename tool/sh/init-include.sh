#!/usr/bin/env bash

## Initialize for ``sh-include PART..``

true "${U_S:="/srv/project-local/user-scripts"}"

source "$U_S/tool/sh/part/fnmatch.sh"
source "$U_S/tool/sh/part/include.sh"
source "$U_S/tool/sh/part/scriptname-d.sh"
source "$U_S/tool/ci/part/print-err.sh"

# Sync: U-s
