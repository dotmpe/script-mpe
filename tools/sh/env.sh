#!/bin/sh

# Keep current shell settings and mute while preparing env, restore at the end
shopts=$-
set +x
set -e

# Restore shell -e opt
case "$shopts"

  in *e* )
      test "$EXIT_ON_ERROR" = "false" -o "$EXIT_ON_ERROR" = "0" && {
        # undo Jenkins opt, unless EXIT_ON_ERROR is on
        echo "[$0] Important: Shell will NOT exit on error (EXIT_ON_ERROR=$EXIT_ON_ERROR)"
        set +e
      } || {
        echo "[$0] Note: Shell will exit on error (EXIT_ON_ERROR=$EXIT_ON_ERROR)"
        set -e
      }
    ;;

  * )
      # Turn off again
      set +e
    ;;

esac

req_vars scriptname || error "scriptname" 1
req_vars scriptdir || error "scriptdir" 1
req_vars SCRIPTPATH || error "SCRIPTPATH" 1
req_vars LIB || error "LIB" 1

req_vars verbosity || export verbosity=7
req_vars DEBUG || export DEBUG=


### Start of build job parameterisation


test -n "$ENV" || {

  note "Branch Names: $BRANCH_NAMES"
  case "$BRANCH_NAMES" in

    # NOTE: Skip build on git-annex branches
    *annex* ) exit 0 ;;

    gh-pages ) ENV=jekyll ; BUILD_STEPS=jekyll ;;
    test* ) ENV=testing ; BUILD_STEPS=test ;;
    dev* ) ENV=development ; BUILD_STEPS=dev ;;
    * ) ENV=development ; BUILD_STEPS="dev test" ;;

  esac
}

case "$ENV" in

    production )
        DESCRIBE="$(git describe --tags)"
        grep '^'$DESCRIBE'$' ChangeLog.rst && {
          echo "TODO: get log, tag"
          exit 1
        } || {
          echo "Not a release: missing change-log entry $DESCRIBE: grep $DESCRIBE ChangeLog.rst)"
        }
      ;;

    testing )
        export BUILD_STEPS=test
      ;;

esac

req_vars Build_Deps_Default_Paths ||
  export Build_Deps_Default_Paths=1
req_vars sudo || export sudo=sudo

req_vars RUN_INIT || export RUN_INIT=
req_vars RUN_FLOW || export RUN_FLOW=
req_vars RUN_OPTIONS || export RUN_OPTIONS=
req_vars BUILD_STEPS || export BUILD_STEPS="\
 dev test "

req_vars TEST_COMPONENTS || export TEST_COMPONENTS="\
 basename-reg "

req_vars TEST_FEATURES || export TEST_FEATURES=
req_vars TEST_OPTIONS || export TEST_OPTIONS=

req_vars TEST_SHELL || export TEST_SHELL=sh

req_vars REQ_SPECS || export REQ_SPECS="\
 helper util-lib str std os match vc-lib vc main\
 box-lib box-cmd box "

req_vars TEST_SPECS || export TEST_SPECS="\
 statusdir htd basename-reg dckr diskdoc esop \
 sh sh-switch rsr edl finfo \
 jsotk-py libcmd_stacked mimereg radical \
 matchbox meta pd "


req_vars INSTALL_DEPS || {
  INSTALL_DEPS=" basher "
  export INSTALL_DEPS
}
req_vars APT_PACKAGES || export APT_PACKAGES=

#    	nodejs npm \
#      	python-dev \
#        realpath uuid-runtime moreutils curl php5-cli

test -n "$TRAVIS_COMMIT" || GIT_CHECKOUT=$TRAVIS_COMMIT

GIT_CHECKOUT=$(git log --pretty=oneline | head -n 1 | cut -f 1 -d ' ')
BRANCH_NAMES="$(echo $(git ls-remote origin | grep -F $GIT_CHECKOUT \
        | sed 's/.*\/\([^/]*\)$/\1/g' | sort -u ))"




### Env of build job parameterisation


note "Build Steps: $BUILD_STEPS"
note "Test Specs: $TEST_SPECS"
note "Required Specs: $REQ_SPECS"




# Restore shell -x opt
case "$shopts" in
  *x* )
    case "$DEBUG" in
      [Ff]alse|0|off|'' )
        # undo verbosity by Jenkins, unless DEBUG is explicitly on
        set +x ;;
      * )
        echo "[$0] Shell debug on (DEBUG=$DEBUG)"
        set -x ;;
    esac
  ;;
esac

# Id: script-mpe/0.0.3-dev tools/sh/env.sh
