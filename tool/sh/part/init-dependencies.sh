#!/usr/bin/env bash


# XXX: Get checkouts, tool installs and rebuild env (PATH etc.)
VND_SRC_PREFIX=$HOME/build
. ./tool/sh/part/env-0-src.sh
. $sh_tool/part/init.sh
$INIT_LOG "note" "" "Installing prerequisite repos" "$VND_SRC_PREFIX"
init-deps dependencies.txt

# Sync: U-S:
