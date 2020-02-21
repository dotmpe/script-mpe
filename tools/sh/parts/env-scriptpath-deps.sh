#!/usr/bin/env bash

# Add user-scripts and dependencies to SCRIPTPATH

type unique-paths >/dev/null 2>&1 || return 101
test -n "${INIT_LOG:-}" || return 109

$INIT_LOG note "env-scriptpath-deps" "Current SCRIPTPATH" "$SCRIPTPATH"

: "${SCRIPTPATH:="$PWD:$PWD/commands:$PWD/contexts"}" # $U_S/src/sh/lib:$U_S/commands"}"
: "${VND_PATHS:="$(unique-paths ~/build $VND_GH_SRC $VND_SRC_PREFIX ~/.basher/cellar/packages)"}" # /src/*/ )"}"

for supportlib in $(grep '^git ' $CWD/dependencies.txt|cut -d' ' -f2);
do
  for vnd_base in $VND_PATHS;
  do
    lib_path="$vnd_base/$supportlib";
    test -f $lib_path/load.bash || continue
    . "$lib_path/load.bash";
  done;
done

$INIT_LOG note "" "Set new SCRIPTPATH" "$SCRIPTPATH"
unset supportlib vnd_base lib_path
export SCRIPTPATH
# Sync: U-S:
