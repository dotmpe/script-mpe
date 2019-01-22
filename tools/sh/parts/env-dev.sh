#!/usr/bin/env bash

test -n "$U_S" -a -d "$U_S" || source ./tools/sh/parts/env-0-u_s.sh # No-Sync
#test -n "${LOG:-}" -a -x "${LOG:-}" || export LOG=$U_S/tools/sh/log.sh

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

# XXX . "$sh_tools/parts/env-init-log.sh"

. "$sh_tools/parts/env-0-src.sh"
. "$sh_tools/parts/env-std.sh"
. "$sh_tools/parts/env-ucache.sh"
#. "$sh_tools/parts/env-scriptpath.sh"

# XXX: remove from env; TODO: disable undefined check during init.sh,
# or when dealing with other dynamic env..

: "${__load_lib:=""}"
: "${lib_loaded:=""}"

sh_lib_include env-0-1-lib-sys env-0-2-lib-os env-0-3-lib-str env-0-4-lib-script

: "${init_sh_boot:=""}"

sh_include env-0-5-lib-log env-0-6-lib-git env-0-7-lib-vc env-0-1-lib-shell

: "${TMPDIR:=/tmp}"
: "${RAM_TMPDIR:=}"
# Sync: U-S:
