#!/usr/bin/env bash
test -z "${sh_env_:-}" && sh_env_=1 || return 98 # Recursion


: "${DEBUG:=""}"
: "${BASH_ENV:=""}"
: "${CWD:="$PWD"}"

export scriptname=${scriptname:-"`basename "$0"`"}

test -n "${sh_util_:-}" || {

  . "${script_util}/util.sh"
  . "${script_util}/parts/print-color.sh"
  print_yellow "sh:util" "Loaded"
}

test -z "$DEBUG" || print_yellow "" "Starting sh:env '$_' '$*' <$0>"

# Keep current shell settings and mute while preparing env, restore at the end
shopts=$-

#test -n "$DEBUG" && {
#    set -x || true;
#}


# Static init to run sh-dev-script based on PWD

test $# -gt 0 || {
  test -e "sh-`dirname "$PWD"`" && {
      set -- "sh-`dirname "$PWD"`"
  }
}

# Customizable user script config
test -e tools/sh/user-env.sh && {
  . "${USER_ENV:="$CWD/tools/sh/user-env.sh"}" || return
  test -z "$DEBUG" ||
    print_green "" "Loaded sh:user:env, continue with sh:env"

} || {

  test -z "$DEBUG" ||
    print_yellow "" "No local sh:user:env, continue with sh:env"
  : "${SCRIPT_ENV:="$CWD/tools/sh/env.sh"}"
  : "${USER_ENV:="$SCRIPT_ENV"}"
}
export SCRIPT_ENV USER_ENV


: "${SCRIPT_SHELL:="$SHELL"}"


func_exists error || ci_bail "std.lib missing"
func_exists req_vars || error "sys.lib missing" 1

req_vars scriptname uname verbosity DEBUG CWD userscript LOG INIT_LOG

set +o nounset # NOTE: apply nounset only during init

# XXX: sync with current user-script tooling; +user-scripts
# : "${script_env_init:=$CWD/tools/sh/parts/env.sh}"
# . "$script_env_init"


# : "${USER_ENV:=tools/sh/env.sh}"
# export USER_ENV

lib_load projectenv


# Restore shell -e opt
#case "$shopts"
#
#  in *e* )
#      test "$EXIT_ON_ERROR" = "false" -o "$EXIT_ON_ERROR" = "0" && {
#        # undo Jenkins opt, unless EXIT_ON_ERROR is on
#        msg="[$0] Shell will NOT exit on error (EXIT_ON_ERROR=$EXIT_ON_ERROR)"
#        test -n "$PS1" && debug "$msg" || note "$msg"
#        set +e
#      } || {
#        msg="[$0] Shell will exit on error (EXIT_ON_ERROR=$EXIT_ON_ERROR)"
#        test -n "$PS1" && warn "$msg" || std_info "$msg"
#      }
#    ;;
#
#  * )
#      # Turn on again
#      test "$EXIT_ON_ERROR" = "false" -o "$EXIT_ON_ERROR" = "0" || set -e
#    ;;
#
#esac




### Start of build job parameterisation

sh_isset SHELLCHECK_OPTS ||
    export SHELLCHECK_OPTS="-e SC2154 -e SC2046 -e SC2015 -e SC1090 -e SC2016 -e SC2209 -e SC2034 -e SC1117 -e SC2100 -e SC2221"

GIT_CHECKOUT="$(git log --pretty=oneline | head -n 1 | cut -f 1 -d ' ' || true)"

BRANCH_NAMES="$(echo $(git ls-remote origin | grep -F "$GIT_CHECKOUT" | sed 's/.*\/\([^/]*\)$/\1/g' | sort -u ))"


project_env_bin node npm lsof

. "$script_util/parts/env-test-feature.sh"

TAP_COLORIZE="script-bats.sh colorize"

test -n "$TEST_RESULTS" || TEST_RESULTS=build/test-results
test -d "$(dirname "$TEST_RESULTS")" || mkdir -vp "$(dirname "$TEST_RESULTS")"



## Determine ENV

case "$ENV_NAME" in development|testing ) ;; *|dev?* )
      test -z "$DEBUG" ||
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

# TODO: fetching tags is no use if checked out with --depth and no
# rechable tags are available. Should check that tags don't threaten to
# go beyond some threshold.

# XXX: CI: git fetch origin --tags --quiet

# TODO: see project-description, 'build' tag based on gitflow/branch-name.
export GIT_DESCRIBE="$(git describe --always)"


## Per-env settings

case "$ENV_NAME" in

    jekyll )
        BUILD_STEPS=jekyll
      ;;

    production )
        grep '^'$GIT_DESCRIBE'$' ChangeLog.rst && {
          echo "TODO: get log, tag"
          exit 1
        } || {
          echo "Not a release: missing change-log entry $GIT_DESCRIBE: grep $GIT_DESCRIBE ChangeLog.rst)"
        }
      ;;

    features/* | dev* )
        BUILD_STEPS="dev test"
      ;;

    testing )
        BUILD_STEPS=dev\ test
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
test -n "$Job_Param_Re" || export Job_Param_Re='^\(Project\|Jenkins\|Build\|Job\|Travis\)_'

# install-dependencies
#test -n "$Build_Deps_Default_Paths" || export Build_Deps_Default_Paths=1
req_vars Build_Deps_Default_Paths || export Build_Deps_Default_Paths=1
req_vars sudo || export sudo=


# BATS tests dependencies

test -n "$Project_Env_Requirements" ||
  export Project_Env_Requirements="bats bats-specs docutils lsof"

test -z "$Build_Offline" && {
  export projectenv_dep_web=1
} || {
  export projectenv_dep_web=0
}

test -n "$Jenkins_Skip" || {
  test "$(whoami)" != jenkins || export Jenkins_Skip=1
}


req_vars BUILD_STEPS || export BUILD_STEPS="\
 dev test "

# Required specs, each of these must test OK
req_vars REQ_SPECS ||

req_vars INSTALL_DEPS || {
  INSTALL_DEPS=" basher "
  export INSTALL_DEPS
}

{
  test "$USER" != "travis" && not_falseish "$SHIPPABLE"
} && {
  req_vars APT_PACKAGES || export APT_PACKAGES="nodejs "\
" python-dev "\
" realpath uuid-runtime moreutils curl php5-cli"
# XXX: dnsutils (dig) has a bunch of perl-base (and CPAN setup) deps I guess?
}
# not on shippable: npm

test -n "$TRAVIS_COMMIT" || GIT_CHECKOUT=$TRAVIS_COMMIT

export PYTHONPATH="$HOME/lib/py:$PYTHONPATH"


#. $script_util/parts/env-basher.sh
#. $script_util/parts/env-logger-stderr-reinit.sh
#. $script_util/parts/env-github.sh
# XXX: user-env?
#. $script_util/parts/env-scriptpath.sh


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

test -z "$DEBUG" || print_green "" "Finished sh:env"

# Id: script-mpe/0.0.4-dev tools/sh/env.sh
