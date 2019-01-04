#!/usr/bin/env bash

export U_S="${U_S:="$CWD"}"

test -n "${LOG:-}" -a -x "${LOG:-}" || export LOG=$U_S/tools/sh/log.sh

: "${hostname:="`hostname -s`"}"

: "${sh_src_base:="/src/sh/lib"}"
: "${sh_util_base:="/tools/sh"}"

: "${scriptpath:="$U_S$sh_src_base"}"
: "${userscript:="$U_S"}"

# Define now, Set/use later
: "${SCRIPTPATH:=""}"
: "${default_lib:=""}"
: "${init_sh_libs:=""}"
: "${LIB_SRC:=""}"

: "${CWD:="$PWD"}"
: "${script_util:="$CWD/tools/sh"}"
: "${ci_util:="$CWD/tools/ci"}"
#: "${script_util:="$userscript/tools/sh"}"
#: "${ci_util:="$userscript/tools/ci"}"
export script_util ci_util

#. "$script_util/parts/env-init-log.sh"

. "$script_util/parts/env-0-src.sh"
. "$script_util/parts/env-std.sh"
. "$script_util/parts/env-ucache.sh"
. "$script_util/parts/env-scriptpath.sh"

# XXX: remove from env; TODO: disable undefined check during init.sh,
# or when dealing with other dynamic env..

: "${__load_lib:=""}"
: "${lib_loaded:=""}"

. "$script_util/parts/env-0-1-lib-sys.sh"
. "$script_util/parts/env-0-2-lib-os.sh"
. "$script_util/parts/env-0-3-lib-str.sh"
. "$script_util/parts/env-0-4-lib-script.sh"

: "${init_sh_boot:=""}"

. "$script_util/parts/env-0-5-lib-log.sh"

. "$script_util/parts/env-0-1-lib-shell.sh"

: "${RAM_TMPDIR:=/tmp}"

# Locate ztombol helpers and other stuff from github
: "${VND_GH_SRC:="/srv/src-local/github.com"}"
: "${VND_SRC_PREFIX:="$VND_GH_SRC"}"
