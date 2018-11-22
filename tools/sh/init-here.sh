#!/bin/sh

# Alternative to init.sh (for project root dir), XXX: setup for new script subenv
# for this project. To get around the Sh no-source-arg limitation, instead of
# env keys instead this evaluates $@ after taking args. And it is still able to
# use $0 to get this scripts pathname and $PWD to add other dir.

# init-here [SRC-Base-Dir] "$@"

scriptpath="$(dirname "$(dirname "$(dirname "$0")" )" )"

test -n "$1" && {
  SCRIPTPATH=$1:$scriptpath
} || {
  SCRIPTPATH=$(pwd -P):$scriptpath
}
shift

# Now include script and run util_init to source other utils
__load_mode=ext . $scriptpath/util.sh

eval "$@"

# Id: script-mpe/0.0.4-dev tools/sh/init-here.sh
