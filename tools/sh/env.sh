#!/bin/sh

# Keep current shell settings and mute while preparing env, restore at the end
shopts=$-
test -n "$DEBUG" && set -x || set +x


# Restore shell -e opt
case "$shopts"

  in *e* )
      test "$EXIT_ON_ERROR" = "false" -o "$EXIT_ON_ERROR" = "0" && {
        # undo Jenkins opt, unless EXIT_ON_ERROR is on
        echo "[$0] Important: Shell will NOT exit on error (EXIT_ON_ERROR=$EXIT_ON_ERROR)"
        set +e
      } || {
        echo "[$0] Note: Shell will exit on error (EXIT_ON_ERROR=$EXIT_ON_ERROR)"
      }
    ;;

  * )
      # Turn on again
      test "$EXIT_ON_ERROR" = "false" -o "$EXIT_ON_ERROR" = "0" || set -e
    ;;

esac

type error >/dev/null 2>&1 || { echo "std.lib missing" >&2 ; exit 1 ; }
type req_vars >/dev/null 2>&1 || error "sys.lib missing" 1
export scriptname scriptpath SCRIPTPATH
var_isset scriptname || error "scriptname=$scriptname" 1
var_isset scriptpath || error "scriptpath=$scriptpath" 1
var_isset SCRIPTPATH || error "SCRIPTPATH=$SCRIPTPATH" 1
#req_vars LIB || error "LIB=$LIB" 1

req_vars verbosity || export verbosity=7
req_vars DEBUG || export DEBUG=


### Start of build job parameterisation

GIT_CHECKOUT=$(git log --pretty=oneline | head -n 1 | cut -f 1 -d ' ')
BRANCH_NAMES="$(echo $(git ls-remote origin | grep -F $GIT_CHECKOUT \
        | sed 's/.*\/\([^/]*\)$/\1/g' | sort -u ))"

project_env_bin node npm lsof

test -n "$TEST_FEATURE_BIN" -o ! -x "./vendor/.bin/behat" ||
    TEST_FEATURE_BIN="./vendor/.bin/behat"
test -n "$TEST_FEATURE_BIN" || TEST_FEATURE_BIN="$(which behat || true)"
test -n "$TEST_FEATURE_BIN" && {
    # Command to run one or all feature tests
    TEST_FEATURE="$TEST_FEATURE_BIN --tags ~@todo&&~@skip --suite default"
    # XXX: --tags '~@todo&&~@skip&&~@skip.travis'
    # Command to print def lines
    TEST_FEATURE_DEFS="$TEST_FEATURE_BIN -dl"
}

test -n "$TEST_FEATURE" || {
    test -n "$TEST_FEATURE_BIN" || TEST_FEATURE_BIN="$(which behave || true)"
    test -n "$TEST_FEATURE_BIN" && {
        TEST_FEATURE="$TEST_FEATURE_BIN --tags '~@todo' --tags '~@skip' -k test"
    }
}

test -n "$TEST_FEATURE" || {
    error "Nothing to test features"
    TEST_FEATURE="echo"
}

TAP_COLORIZE="script-bats.sh colorize"

test -n "$TEST_RESULTS" || TEST_RESULTS=build/test-results-specs.tap
test -d "$(dirname "$TEST_RESULTS")" || mkdir -vp "$(dirname "$TEST_RESULTS")"



## Determine ENV

case "$ENV_NAME" in dev|testing ) ;; *|dev?* )
      echo "Warning: No env '$ENV_NAME', overriding to 'dev'" >&2
      export ENV_NAME=dev
    ;;
esac

test -n "$ENV_NAME" || {

  note "Branch Names: $BRANCH_NAMES"
  case "$BRANCH_NAMES" in

    # NOTE: Skip build on git-annex branches
    *annex* ) exit 0 ;;

    gh-pages ) ENV_NAME=jekyll ;;
    test* ) ENV_NAME=testing ;;
    dev* ) ENV_NAME=development ;;
    * ) ENV_NAME=development ;;

  esac
}

## Per-env settings

case "$ENV_NAME" in

    jekyll )
        BUILD_STEPS=jekyll
      ;;

    production )
        DESCRIBE="$(git describe --tags)"
        grep '^'$DESCRIBE'$' ChangeLog.rst && {
          echo "TODO: get log, tag"
          exit 1
        } || {
          echo "Not a release: missing change-log entry $DESCRIBE: grep $DESCRIBE ChangeLog.rst)"
        }
      ;;

    features/* | dev* )
        BUILD_STEPS="dev test"
      ;;

    testing )
        BUILD_STEPS=test
      ;;

    * )
        error "ENV '$ENV_NAME'" 1
      ;;

esac



## Defaults


# Sh
test -n "$Build_Debug" ||       export Build_Debug=
test -n "$Build_Offline" ||       export Build_Offline=
test -n "$Dry_Run" ||           export Dry_Run=

# Sh (projectenv.lib)
test -n "$Env_Param_Re" || export Env_Param_Re='^\(ENV\|ENV_NAME\|NAME\|TAG\|ENV_.*\)='
test -n "$Job_Param_Re" ||
  export Job_Param_Re='^\(Project\|Jenkins\|Build\|Job\)_'

# install-dependencies
#test -n "$Build_Deps_Default_Paths" || export Build_Deps_Default_Paths=1
req_vars Build_Deps_Default_Paths || export Build_Deps_Default_Paths=1
req_vars sudo || export sudo=


# BATS tests dependencies

test -n "$Project_Env_Requirements" ||
  export Project_Env_Requirements="bats bats-specs docutils lsof"
test -n "$ProjectTest_BATS_Specs" || export ProjectTest_BATS_Specs="tests/bats/{,*-}spec.bats"

test -z "$Build_Offline" && {
  export projectenv_dep_web=1
} || {
  export projectenv_dep_web=0
}

test -n "$Jenkins_Skip" || {
  test "$(whoami)" != jenkins || export Jenkins_Skip=1
}


req_vars RUN_INIT || export RUN_INIT=
req_vars BUILD_STEPS || export BUILD_STEPS="\
 dev test "

req_vars TEST_SHELL || export TEST_SHELL=sh

# Required specs, each of these must test OK
req_vars REQ_SPECS ||
  export REQ_SPECS="util 1_1-helper"\
" str sys os std stdio argv bash match.lib vc.lib matchbox src main"\
" sh box-lib pd-meta esop"

# Specs for report but not counting in final test-result judgement
req_vars TEST_SPECS || \
  export TEST_SPECS="statusdir htd basename-reg dckr"\
" rsr edl finfo vc match"\
" jsotk-py box box-cmd libcmd_stacked mimereg radical"\
" meta pd disk diskdoc"

req_vars INSTALL_DEPS || {
  INSTALL_DEPS=" basher "
  export INSTALL_DEPS
}

{
  test "$USER" != "travis" && not_falseish "$SHIPPABLE"
} && {
  req_vars APT_PACKAGES || export APT_PACKAGES="nodejs"\
" perl python-dev"\
" realpath uuid-runtime moreutils curl php5-cli"
}
# not on shippable: npm

test -n "$TRAVIS_COMMIT" || GIT_CHECKOUT=$TRAVIS_COMMIT



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

# Id: script-mpe/0.0.4-dev tools/sh/env.sh
