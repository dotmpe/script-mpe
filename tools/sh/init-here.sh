#!/bin/sh

# Alternative to init.sh (for project root dir), XXX: setup for new script subenv
# for this project. To get around the Sh no-source-arg limitation, instead of
# env keys instead this evaluates $@ after taking args. And it is still able to
# use $0 to get this scripts pathname and $PWD to add other dir.

# <script_util>/init-here.sh [SCRIPTPATH] [boot-script] [boot-libs] "$@"

test -n "$sh_util_base" || sh_util_base=/tools/sh

scriptpath="$(dirname "$(dirname "$(dirname "$0")" )" )"
script_util="$(dirname "$(dirname "$(dirname "$0")" )" )$sh_util_base"

test -n "$1" && {
  SCRIPTPATH=$1:$scriptpath
} || {
  SCRIPTPATH=$(pwd -P):$scriptpath
}


# Now include module loader with `lib_load` by hand
util_mode=ext . $scriptpath/util.sh

shift 3

eval "$@"

# Id: script-mpe/0.0.4-dev tools/sh/init-here.sh
