#!/usr/bin/env bash

test -n "${U_S-}" || . ~/.local/etc/profile.d/_local.sh # Static user config
test -d "${U_S-}" || { $LOG error "" "U-S dir missing"; exit 1; }

ENV_DEV=1

: "${hostname:="`hostname -s`"}"

: "${sh_src_base:="/src/sh/lib"}"
: "${sh_util_base:="/tools/sh"}"
: "${ci_util_base:="/tools/ci"}"

: "${scriptpath:="$CWD"}" # No-Sync
: "${userscript:="$U_S"}"

# Define now, Set/use later
: "${SCRIPTPATH:=""}"
: "${default_lib:=""}"
: "${init_sh_libs:=""}"
: "${LIB_SRC:=""}"

: "${CWD:="$PWD"}"
: "${sh_tools:="$CWD$sh_util_base"}"
: "${ci_tools:="$CWD$ci_util_base"}"

type sh_include >/dev/null 2>&1 || . $sh_tools/init-include.sh

sh_include env-0-src env-std env-ucache

# XXX: remove from env; TODO: disable undefined check during init.sh,
# or when dealing with other dynamic env..

sh_include env-0-1-lib-sys env-0-2-lib-os

sh_include env-0-6-lib-git env-0-1-lib-shell

sh_include trueish

: "${TMPDIR:=/tmp}"
: "${RAM_TMPDIR:=}"
# Sync: U-S:
