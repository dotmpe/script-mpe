#!/bin/sh

test -e "$U_S" || unset U_S

test -e "$U_S" || U_S=$HOME/project/user-scripts
test -e "$U_S" || U_S=$HOME/build/user-tools/user-scripts
test -e "$U_S" || U_S=/srv/project-local/user-scripts

# Sync: U-S:tools/sh/parts/env-0-u_s.sh
# Id: script-mpe/0.0.4-dev tools/sh/parts/env-0-u_s.sh
