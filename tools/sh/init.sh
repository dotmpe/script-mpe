#!/bin/sh

# Must be started from project root.
# Import minimal setup and shell util functions.
test -n "$scriptpath" || export scriptpath="$(pwd -P)"

# if not provided, auto-setup env
# assuming execution starts in script dir (project root)
test -n "$SCRIPTPATH" || {

  test -n "$LIB" && echo LIB=$LIB || {
    test -n "$scriptpath" &&
      LIB=$scriptpath ||
      LIB=$(cd $(dirname $(dirname $0)); pwd -P )
    test -n "$LIB" || {
      echo "Missing LIB" >&2; exit 99
    }
    export LIB
  }
  #test -n "$LIB" || export LIB="$( test -n "$scriptpath" &&
  #    echo $scriptpath || ( cd $(dirname $(dirname $0)); pwd -P ))"

  #export SCRIPTPATH="$( case "$LIB" in /* ) echo $LIB ;; * )
  #    echo $(cd "$LIB"; pwd -P)
  #  ;; esac )"

  SCRIPTPATH=$LIB
  # get absolute path for scripts lib dir if LIB is relative
  case "$LIB" in "/"* ) ;; * )
    SCRIPTPATH="$(cd "$LIB"; pwd -P)"
  ;;esac
  export SCRIPTPATH
}

# Now include script and run util_init to source other utils
#f_lib_load=tools-sh-init . $scriptpath/util.sh load-ext

__load_mode=boot . ./util.sh
lib_load projectenv env-deps


# Id: script-mpe/0.0.4-dev tools/sh/init.sh
