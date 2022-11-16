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
  BUILD_STARTDIR=$CWD
  BUILD_BASE=${REDO_BASE:?}
  BUILD_ID=$REDO_RUNID
  default_do_attrs || return
  true "${ENV:="dev"}"
  true "${APP:="Script.mpe/0.0.4-dev"}"
  true "${ENV_BUILD:="tools/redo/env.sh"}"
  true "${BUILD_ENV_DEF:="attributes build-rules rule-params defaults redo--"}"
  BUILD_TOOL=redo
  local sub="${BUILD_STARTDIR:${#BUILD_BASE}}"
  BUILD_SCRIPT=${sub}${sub:+/}default.do
  declare -x UC_LOG_BASE="${BUILD_SCRIPT}[$$]"

  test "unset" = "${log_key-unset}" || {
      unset log_key
      declare +x log_key
    }

  # Use ENV-BUILD as-is when given, or fall-back to default built-in method.
  test -e "$ENV_BUILD" && {
    . "$ENV_BUILD" || return
  } || {
    default_do_env_default
  }
}

default_do_env_default () # ~ # Default method to prepare redo shell profile
{
  $LOG info ":default.do:env-default" "Starting default env..." "${BUILD_TARGET:?}"
  true "${BUILD_ENV_CACHE:="${PROJECT_CACHE:=".meta/cache"}/redo-env.sh"}"

  # Built-in recipe for redo profile
  test "${BUILD_TARGET:?}" = "$BUILD_ENV_CACHE" && {

    $LOG info ":default.do:env-default" "Building cache..." "${BUILD_ENV_CACHE:?}"
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

    test -e "$BUILD_ENV_CACHE" || {
      #build_env_targets_default &&
      build_env_default
      return
    }

    # For every other target, source the built profile and continue.
    redo-ifchange "$BUILD_ENV_CACHE" || return
    $LOG debug ":default.do:env-default" "Sourcing cache..." "${BUILD_ENV_CACHE:?}"
    source "$BUILD_ENV_CACHE"
  }
}
# Export: build-target-env-default

build_env_default ()
{
  $LOG info ":build-env-default" "Starting default env..." "${BUILD_TARGET:?}"
  test "unset" != ${CWD-unset} || declare -l CWD
  test -n "${BUILD_PATH:-}" || declare -l BUILD_PATH
  true "${CWD:=$PWD}"

  # No need loading script used as entry point again
  test "unset" != ${build_source[*]-unset} || {
    declare -gA build_source
  }
  declare rp
  rp=$(realpath "$0")
  build_source[$rp]=$0

  # Projects should execute their own BUILD_PATH, a default is set by this lib
  # but +U-s does not have super-projects.
  test "$rp" != "$(realpath "$U_S")/src/sh/lib/build.lib.sh" || BUILD_PATH=$U_S

  # Either set initial build-path as argument, or provide entire
  # Env-Buildpath as env. Standard is to use hard-coded default sequence, and
  # only establish that sequence determined after loading specififed or or
  # local build-lib, the former must exist while the latter is optional.
  test $# -eq 0 && {
    ! test -e "$CWD/build-lib.sh" || {
      build_source "$CWD/build-lib.sh" || return
    }
  } || {
    test -e "${1:?}/build-lib.sh" || {
      $LOG error :build-env-default "Expected build-lib" "$1" ; return 1
    }
    build_source "$1/build-lib.sh" || return
  }

  true "${BUILD_PATH:=$CWD ${BUILD_BASE:?} ${BUILD_STARTDIR:?}}"

  declare -l dir
  for dir in ${BUILD_PATH:?}
  do
    { test "unset" = "${build_source[$dir]-unset}" &&
      test -e "$dir/build-lib.sh"
    } || continue
    build_source "$dir/build-lib.sh" || return
    set -- "$@" "$dir"
  done
  $LOG debug :build-env-default "Found build libs" "$*"

  # If this script is the entry point, there is no need to load it again.
  # Could make this a lot shorter but want to warn about Build-Entry-Point.
  { test -n "${build_entry_point:-}" &&
    fnmatch "build*" "${build_entry_point:-}"
  } && {

    # If the entry point is build*, then this is the /expected/ source.
    # however we already added the entry-point script above
    local bl="${U_S:?}/src/sh/lib/build.lib.sh"
    rp=$(realpath "$bl")
    ! test "unset" = "${build_source[$rp]-unset}" ||
      $LOG warn ":build-env-default" \
        "Expected build.lib entry point but was" "$0" && false

  } || {
    build_source "${U_S:?}/src/sh/lib/build.lib.sh"
  }

  build_lib_load || return
  $LOG debug :build-env-default "Done"
}
# Export: build-env-default

build_source ()
{
  declare -p build_source >/dev/null 2>&1 || env__def__build_source

  declare rp bll
  test "${1:0:1}" != "/" || set -- "$(realpath "$1" --relative-to "${CWD:?}")"

  rp=$(realpath "$1")
  # XXX:
  #redo-ifchange "$1" && rp=$(realpath "$1") || {
  #  $LOG error :build:source "Error during redo-ifchange" "$1:E$?" ; return 1
  #}
  test -n "${build_source[$rp]-}" && return
  $LOG info :build:source "Found build source" "$1"
  {
    build_source[$rp]=$1 &&
    source "$1"
  } || {
    $LOG error :build:source "Error loading source" "$1:E$?" ; return 1
  }
  $LOG debug :build:source "Loading build source" "$1"
  ! sh_fun build__lib_load && return
  build__lib_load || bll=$?
  # XXX: may be keep this per-source path but dont need it anyway..
  #build_source_[]=$(typeset -f build__lib_load)
  unset -f build__lib_load
  return ${bll:-0}
}

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

sh_fun ()
{
  test "$(type -t "$1")" = function
}

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
  local r=$? lastarg=$_
  ! sh_fun stderr_ ||
    stderr_ "! $0: Error in recipe for '${BUILD_TARGET:?}': E$r" 0
  $LOG error ":on-error" "In recipe for '${BUILD_TARGET:?}' ($lastarg)" "E$r"
  exit $r
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

    ${HELP_TARGET:-help}|-help )    build-always
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
