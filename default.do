#!/usr/bin/env bash

# The main project redo script controls project lifecycle and workflows.

# Created: 2020-08-31

default_do_attrs ()
{
  true "${PROJECT_ATTR:=$(sh_path=$CWD any=true first_only=true \
    default_do_lookup attributes .attributes ${PROJECT_META:-.meta}/attributes )}"
  test -z "${PROJECT_ATTR:-}" && return

  true "${PROJECT_CACHE:="${PROJECT_META:-.meta}/cache"}"

  test "${REDO_TARGET:?}" = "${PROJECT_CACHE:?}/attributes.sh" && {
    build_env_default || return
    test -d "$PROJECT_CACHE" || mkdir -vp "$PROJECT_CACHE" >&2
    redo-ifchange "${PROJECT_ATTR:?}" &&
    attributes_sh "${PROJECT_ATTR:?}"
    exit
  }
  redo-ifchange "${PROJECT_CACHE:?}/attributes.sh" &&
  source "${PROJECT_CACHE:?}/attributes.sh"
}

default_do_env () # ~ # Prepare shell profile with build-target handler
{
  CWD=${REDO_STARTDIR:?}
  default_do_attrs || return
  true "${ENV:="dev"}"
  true "${APP:="Script.mpe/0.0.4-dev"}"
  true "${ENV_BUILD:="tools/redo/env.sh"}"

  true "${BUILD_ENV_DEF:="attributes build-rules rule-params defaults redo--"}"
  true "${BUILD_TOOL:=redo}"

  # Use ENV-BUILD as-is when given, or fall-back to default built-in method.
  test -e "$ENV_BUILD" && {
    . "$ENV_BUILD" || return
  } || {
    default_do_env_default
  }
}

default_do_env_default () # ~ # Default method to prepare redo shell profile
{
  true "${BUILD_ENV_CACHE:="${PROJECT_CACHE:=".meta/cache"}/redo-env.sh"}"

  # Built-in recipe for redo profile
  test "${REDO_TARGET:?}" = "$BUILD_ENV_CACHE" && {

    $LOG info ":redo-env" "Building cache..." "tools/redo/env.sh"
    build_env_default || return

    # Load additional local build-env parameters
    true "${ENV_BUILD_ENV:=$( sh_path=$CWD default_do_lookup \
        .build-env.sh \
        .meta/build-env.sh \
        tools/redo/build-env.sh )}"
    test -z "${ENV_BUILD_ENV:-}" || {
      redo-ifchange "$ENV_BUILD_ENV" || return
      . "$ENV_BUILD_ENV" || return
    }

    # Finally run some steps to generate the profile
    quiet=true build_env
    exit

  } || {

    # For every other target, source the built profile and continue.
    $LOG debug ":redo-env" "Sourcing cache..." "tools/redo/env.sh"
    redo-ifchange "$BUILD_ENV_CACHE" &&
    source "$BUILD_ENV_CACHE"
  }
}
# Export: build-target-env-default

build_env_default ()
{
  local depsrc
  for depsrc in "${U_S:?}/src/sh/lib/build.lib.sh" "${CWD:?}/build-lib.sh"
  do
    test -e "$depsrc" || continue
    redo-ifchange "$depsrc" &&
    source "$depsrc" || return
  done
  build_lib_load
}
# Export: build-env-default

default_do_lookup () # ~ <Paths...> # Lookup paths at PATH.
# Regular source or command do not look up paths, only local (base) names.
{
  local n e bd found sh_path=${sh_path:-} sh_path_var=${sh_path_var:-PATH}

  test -n "$sh_path" || {
    sh_path=${!sh_path_var:?}
  }

  for n in "${@:?}"
  do
    found=false
    for bd in $(echo "$sh_path" | tr ':' '\n')
    do
      for e in ${sh_exts:-""}
      do
        test -e "$bd/$n$e" || continue
        echo "$bd/$n$e"
        found=true
        break 2
      done
    done
    ${found} && {
      ${any:-false} && {
        ${first_only:-true} && return || continue
      }
    } || {
      ${any:-false} && continue || return
    }
  done
  ${found}
}
# Copy: sh-lookup

sh_mode ()
{
  test $# -eq 0 && {
    # XXX: sh-mode summary
    echo "$0: sh-mode: $-" >&2
    trap >&2
  } || {
    while test $# -gt 0
    do
      case "${1:?}" in
          ( build )
                set -CET &&
                trap "build_error_handler" ERR
              ;;
          ( dev )
                set -hET &&
                shopt -s extdebug
              ;;
          ( strict ) set -euo pipefail ;;
          ( * ) stderr_ "! $0: sh-mode: Unknown mode '$1'" 1 || return ;;
      esac
      shift
    done
  }
}
# Copy: sh-mode

build_error_handler ()
{
  stderr_ "! $0: Error in recipe for '${BUILD_TARGET:?}': E$?" $?
  exit $?
}

default_do_main ()
{
  BUILD_TARGET=${1:?}
  BUILD_TARGET_BASE=$2
  BUILD_TARGET_TMP=$3

  sh_mode dev strict build || return

  default_do_env || return

  redo-ifchange "${CWD:?}/default.do" || return

  case "${1:?}" in

    # 'all' is the only special redo-builtin (it does not show up in
    # redo-{targets,sources}), everything else are proper targets. Anything
    # seems to be accepted, '-' prefixed arguments are parsed as redo options
    # but after '--' we can pass targets that start with '-' as well.

    -env )     build-always && build_ env-sh >&2  ;;
    -info )    build-always && build_ info >&2 ;;
    -ood )     build-always && build-ood >&2 ;;
    -sources ) build-always && build-sources >&2 ;;
    -targets ) build-always && build-targets >&2 ;;
    "??"* )
        BUILD_TARGET=${BUILD_TARGET:2}
        BUILD_TARGET_BASE=${BUILD_TARGET_BASE:2}
        BUILD_TARGET_TMP=${BUILD_TARGET_TMP:2}
        build-always && build_ which "${BUILD_TARGET:?}" >&2 ;;
    "?"* )
        BUILD_TARGET=${BUILD_TARGET:1}
        BUILD_TARGET_BASE=${BUILD_TARGET_BASE:1}
        BUILD_TARGET_TMP=${BUILD_TARGET_TMP:1}
        build-always && build_ for-target "${BUILD_TARGET:?}" >&2 ;;

    -help|:help )    build-always
        echo "Usage: ${BUILD_TOOL-(BUILD_TOOL unset)} [${build_main_targets// /|}]" >&2
        echo "Default target (all): ${build_all_targets-(unset)}" >&2
        echo "Version: ${APP-(APP unset)}" >&2
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
        build_ target
      ;;

  esac
  # End build if handler has not exit already
  exit $?
}

test -z "${REDO_RUNID:-}" ||
    default_do_main "$@"

# Id: BIN:default.do                                               ex:ft=bash:
# Sync: U-s
