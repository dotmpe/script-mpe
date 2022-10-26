#!/usr/bin/env bash

# The main project redo script controls project lifecycle and workflows.

# Created: 2020-08-31

default_do_env () # ~ # Prepare shell profile with build-target handler
{
  true "${ENV:="dev"}"
  true "${APP:="Script.mpe/0.1-alpha"}"
  true "${ENV_BUILD:="tools/redo/env.sh"}"

  true "${BUILD_ENV_DEF:="attributes build-rules rule-params defaults redo--"}"
  true "${BUILD_TOOL:=redo}"
  true "${PROJECT_CACHE:=.meta/cache}"

  CWD=$REDO_BASE

  # Use ENV-BUILD as-is when given, or fall-back to default built-in method.
  test -e "$ENV_BUILD" && {
    . "$ENV_BUILD" || return
  } || {
    default_do_env_default
  }
}

default_do_env_default () # ~ # Default method to prepare redo shell profile
{
  true "${REDO_ENV_CACHE:="${PROJECT_CACHE:-".meta/cache"}/redo-env.sh"}"

  # Built-in recipe for redo profile
  test "${REDO_TARGET:?}" = "$REDO_ENV_CACHE" && {

    #true "${ENV_BUILD_ENV:="tools/redo/build-env.sh"}"

    # Allow to build build-env profile as well.
    #test "${ENV_BUILD_BUILD_ENV:-0}" != "1" || {
    #  build-ifchange "$ENV_BUILD_ENV" || return
    #}

    #test ! -e "$ENV_BUILD_ENV" || {
    #  . "$ENV_BUILD_ENV" || return
    #}

    # Add current file to deps
    #redo-ifchange "${REDO_BASE:?}/tools/redo/env.sh" &&

    # Finally run some steps to generate the profile
    source "${U_S:?}/src/sh/lib/build.lib.sh" &&
    quiet=true build_env
    exit

  } || {

    # For every other target, source the built profile and continue.
    redo-ifchange "$REDO_ENV_CACHE" &&
    source "$REDO_ENV_CACHE"
  }
}

default_do_main ()
{
  redo-ifchange "${REDO_BASE:?}/default.do" || return

  BUILD_TARGET=$1
  BUILD_TARGET_BASE=$2
  BUILD_TARGET_TMP=$3

  set -euo pipefail

  default_do_env || return

  case "$1" in

    # 'all' is the only special redo-builtin (it does not show up in
    # redo-{targets,sources}), everything else are proper targets. Anything
    # seems to be accepted, '-' prefixed arguments are parsed as redo options
    # but after '--' we can pass targets that start with '-' as well.

    -env )     build-always && build_env_sh >&2  ;;
    -info )    build-always && build_info >&2 ;;
    -ood )     build-always && build-ood >&2 ;;
    -sources ) build-always && build-sources >&2 ;;
    -targets ) build-always && build-targets >&2 ;;

    "??"* )
        BUILD_TARGET=${BUILD_TARGET:1}
        BUILD_TARGET_BASE=${BUILD_TARGET_BASE:1}
        BUILD_TARGET_TMP=${BUILD_TARGET_TMP:1}
        build_which "$BUILD_TARGET" >&2 ;;

    "?"* )
        BUILD_TARGET=${BUILD_TARGET:1}
        BUILD_TARGET_BASE=${BUILD_TARGET_BASE:1}
        BUILD_TARGET_TMP=${BUILD_TARGET_TMP:1}
        build_for_target >&2 ;;

    help|-help )    build-always
              echo "Usage: $BUILD_TOOL [${build_main_targets// /|}]" >&2
      ;;

    # Default build target
    all|@all|:all )     build-always && build $build_all_targets
      ;;

    #test-all) build-always && $component_test $( expand_spec_src units )

    .build/tests/*.tap ) default_do_include \
          "tools/redo/parts/_build_tests_*.tap.do" "$@"
      ;;

    * )
        # Build target using alternative methods if possible.
        build_target
        exit
      ;;

  esac
}

test -z "${REDO_RUNID:-}" ||
    default_do_main "$@"

# Id: BIN:default.do                                               ex:ft=bash:
# Sync: U-s
