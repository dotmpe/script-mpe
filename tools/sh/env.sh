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

req_vars scriptname || error "scriptname=$scriptname" 1
req_vars scriptpath || error "scriptpath=$scriptpath" 1
req_vars SCRIPTPATH || error "SCRIPTPATH=$SCRIPTPATH" 1
#req_vars LIB || error "LIB=$LIB" 1

req_vars verbosity || export verbosity=7
req_vars DEBUG || export DEBUG=


### Start of build job parameterisation

GIT_CHECKOUT=$(git log --pretty=oneline | head -n 1 | cut -f 1 -d ' ')
BRANCH_NAMES="$(echo $(git ls-remote origin | grep -F $GIT_CHECKOUT \
        | sed 's/.*\/\([^/]*\)$/\1/g' | sort -u ))"

project_env_bin node npm lsof

# Run tests for DUT's
project_test() # [Units...|Comps..]
{
  set -- $(project_tests "$@")
  local failed=/tmp/htd-project-test-$(uuidgen).failed
  while test $# -gt 0
  do
    case "$1" in
        *.feature ) $TEST_FEATURE -- "$1" || touch $failed ;;
        *.bats ) {
                bats "$1" || touch $failed
            } | $TAP_COLORIZE ;;
        *.py ) python "$1" || touch $failed ;;
    esac
    shift
  done

  test -e "$failed" && { rm "$failed" ; return 1 ; }
  note "Project test completed succesfully"
}

# Echo test file names
project_tests() # [Units..|Comps..]
{
  test -n "$1" || set -- "*"
  while test $# -gt 0
  do
      any_unit "$1"
      any_feature "$1"
      case "$1" in *.py|*.bats|*.feature )
          test -e "$1" && echo "$1" ;;
      esac
    shift
  done | sort -u
}

any_unit()
{
  test -n "$1" || set -- "*"
  while test $# -gt 0
  do
    c=*_- mkid "$1"
    mkvid "$1"
    for x in test/py/$id.py test/py/mod_$vid.py test/$id-lib-spec.bats test/$id-spec.bats test/$id.bats
    do
      test -e "$x" && echo $x
      continue
    done
    shift
  done
}

test -x "./vendor/.bin/behat" && {
    TEST_FEATURE_BIN="./vendor/.bin/behat"
    # Command to run one or all feature tests
    TEST_FEATURE="$TEST_FEATURE_BIN --tags ~@todo&&~@skip --suite default"
    # Command to print def lines
    TEST_FEATURE_DEFS="$TEST_FEATURE_BIN -dl"
} || {
    test -x "$(which behave)" && {
        TEST_FEATURE_BIN="behave"
        TEST_FEATURE="$TEST_FEATURE_BIN --tags '~@todo' --tags '~@skip' -k test"
    }
}

TAP_COLORIZE="script-bats.sh colorize"

any_feature()
{
  test -n "$1" || set -- "*"
  while test $# -gt 0
  do
    c=_- mkid "$1"
    for x in test/$id.feature test/$id-lib-spec.feature test/$id-spec.feature
    do
      test -e "$x" && echo $x
      continue
    done
    shift
  done
}

test_any_feature()
{
  pwd -P
  info "Test any feature '$*'"
  test -n "$1" && {
    local features="$(any_feature "$@" | tr '\n' ' ')"
    test -n "$features" || error "getting features '$@'" 1
    note "Features: $features"
    $TEST_FEATURE $features || return $?;

  } || {
    $TEST_FEATURE || return $?;
  }
}

test_watch()
{
  local watch_flags=" -w test/bootstrap/FeatureContext.php "\
" -w package.yaml -w '*.sh' -w htd "\
" -w tools/sh/env.sh "
  local tests="$(project_tests "$@")"
  test -n "$tests" || error "getting tests '$@'" 1
  note "Watching files: $(echo $tests | tr '\n' ' ')"
  watch_flags="$watch_flags $(echo $tests | sed 's/^/-w /g')"
  #eval nodemon -x \"htd run project-test $(echo $tests | tr '\n' ' ')\" $watch_flags || return $?;
  note "Watch flags '$watch_flags'"
  nodemon -x "htd run project-test $(echo $tests | tr '\n' ' ')" $watch_flags || return $?;
}

feature_watch()
{
  watch_flags=" -w test/bootstrap/FeatureContext.php "
  test -n "$1" && {
    local features="$(any_feature "$@")"
    note "Watching files: $features"
    watch_flags="$watch_flags $(echo $features | sed 's/^/-w \&/')"
    nodemon -x "$TEST_FEATURE $(echo $features | tr '\n' ' ')" $watch_flags || return $?;

  } || {
    $TEST_FEATURE || return $?;
    nodemon -x "$TEST_FEATURE" $watch_flags -w test || return $?;
  }
}

retest()
{
  test -n "$1" || set -- totest.list "$2"
  test -n "$2" || set -- "$1" tested.list
  test -s "$1" || {
    project_tests | sort -u > $1
  }
  while true
  do
    # TODO: do-test with lst watch
    cat "$1" | sponge | while read test
    do
        grep -qF "$test" "$2" && continue
        wc -l "$@"
        htd run test "$test" && {
          echo $test >> "$2"
        } || echo "Failure <$test>"
    done
    sleep 1 || return
    cat "$2" | sort -u > "$2.tmp"
    diff -q "$1" "$2.tmp" && {
      note "All tests completed" && rm "$@" "$2.tmp" && break
    } || {
      mv "$2.tmp" "$2"
      sleep 5 &&
        comm -2 -3 "$2" "$1" &&
        continue
    }
  done
}



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
req_vars RUN_FLOW || export RUN_FLOW=
req_vars RUN_OPTIONS || export RUN_OPTIONS=
req_vars BUILD_STEPS || export BUILD_STEPS="\
 dev test "

req_vars TEST_COMPONENTS || export TEST_COMPONENTS="\
 basename-reg "

req_vars TEST_FEATURES || export TEST_FEATURES=
req_vars TEST_OPTIONS || export TEST_OPTIONS=

req_vars TEST_SHELL || export TEST_SHELL=sh

# Required specs, each of these must test OK
req_vars REQ_SPECS ||
  export REQ_SPECS="util 1_1-helper"\
" str sys os std stdio argv bash match matchbox src vc main"\
" sh box-lib box-cmd box pd-meta esop disk diskdoc"

# Specs for report but not counting in final test-result judgement
req_vars TEST_SPECS || \
  export TEST_SPECS="statusdir htd basename-reg dckr"\
" rsr edl finfo vc"\
" jsotk-py libcmd_stacked mimereg radical"\
" meta pd"

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
# not o shippable: npm

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
