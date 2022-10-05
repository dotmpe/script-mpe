#!/usr/bin/env bash
# Created: 2020-08-31
set -euo pipefail

# The main project redo script controls project lifecycle and workflows.

version="Script.mpe/0.1-alpha"

default_do_include () # Build-Part Target-File Target-Name Temporary
{
  local build_part="$1"

  $LOG "info" ":part:$2" "Building include" "$1"
  build-ifchange "$build_part" || return
  shift

  $LOG "debug" ":part:$1" "Sourcing include" "$build_part"
  source "$build_part"
}

default_do_main ()
{
  : ${CWD:=$PWD}

  command -v build- >/dev/null || build- () {
    build_entry_point=build- \
      source "${U_S:?}/src/sh/lib/build.lib.sh"; }

  true "${BUILD_TOOL:=redo}"
  true "${BUILD_TARGET:=$1}"

  # TODO: use boot-for-target to load script deps
  redo_env="$(quiet=true build- boot)" || {
    $LOG "error" "" "While loading build-env" "E$?" $?
    return
  }

  eval "$redo_env" || {
    $LOG "error" "" "While reading build-env" "E$?" $?
    return
  }


  # Keep short build sequences in this file (below in the case/easc), but move
  # larger build-scripts to separate files to prevent unnecessary builds from
  # updates to the default.do
  # Alternatively we fall back to build-components from build.lib.sh that reads
  # rules to generate source-to-target build specs.

  local target="$(echo ${BUILD_TARGET:?} | tr './' '_')" part
  part=$( build_part_lookup $target.do ${build_parts_bases:?} ) && {

    { build_init__redo_env_target_ || return
      build_init__redo_libs_ "$@" || return
    } >&2

    $LOG "notice" ":part:$1" "Building part" "$PWD:$0:$part"
    default_do_include $part "$@"
    exit $?
  }

  $LOG "info" ":main:$1" "Selecting target" "$PWD:$0"
  case "$1" in

    # 'all' is the only special redo-builtin (it does not show up in
    # redo-{targets,sources}), everything else are proper targets. Anything
    # seems to be accepted, '-' prefixed arguments are parsed as redo options
    # but after '--' to separate arguments those can start with '-' as well.

    :env )     build-always && build_env_sh >&2  ;;
    :info )    build-always && build_info ;;
    :sources ) build-always && build-sources >&2 ;;
    :targets ) build-always && build-targets >&2 ;;
    # XXX: see also build-whichdo, build-log

    help|:help )    build-always
              echo "Usage: $BUILD_TOOL [${build_main_targets// /|}]" >&2
      ;;

    # Default build target
    all|@all|:all )     build-always && build $build_all_targets
      ;;

    #test-all) build-always && $component_test $( expand_spec_src units )

    .build/tests/*.tap ) default_do_include \
          "tools/redo/parts/_build_tests_*.tap.do" "$@"
      ;;


    # Build without other do-files, based on .build-rules.txt
    * )
        build_rules_for_target "$@" || return

        test "$1" != "${BUILD_RULES-}" -a -s "${BUILD_RULES-}" || {
          # Prevent redo self.id != src.id assertion failure
          $LOG alert ":build-component:$1" \
            "Cannot build rules table from empty table" "${BUILD_RULES-null}" 1
          return
        }

        # Shortcut execution for simple aliases, but takes literal values only
        { build_init__redo_env_target_ || return
        } >&2
        build_env_rule_exists "$1" && {
          build_env_targets
          exit
        }

        # Run build based on matching rule in BUID_RULES table

        build_rule_exists "$1" || {
          #print_err "error" "" "Unknown target, see '$BUILD_TOOL help'" "$1"
          $LOG "error" "" "Unknown target, see '$BUILD_TOOL help'" "$1" $?
          return
        }

        $LOG "notice" ":exists:$1" "Found build rule for target" "$1"

        { build_init__redo_libs_ "$@" || return
        } >&2
        build_components "$1" "" "$@"
        exit
      ;;

  esac
}

default_do_main "$@"

# Id: BIN:default.do                                               ex:ft=bash:
# Sync: U-s
