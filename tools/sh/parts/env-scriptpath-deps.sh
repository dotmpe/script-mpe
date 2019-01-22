#!/usr/bin/env bash

# Add user-scripts and dependencies to SCRIPTPATH

type unique-paths >/dev/null 2>&1 || return
test -n "${INIT_LOG:-}" || return 102

: "${SCRIPTPATH:="$U_S/src/sh/lib"}"
: "${VND_PATHS:="$(unique-paths $HOME/build ~/.basher/cellar/packages $VND_GH_SRC $VND_SRC_PREFIX)"}" # /src/*/ )"}"

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
