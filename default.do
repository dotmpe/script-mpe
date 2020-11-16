#!/usr/bin/env bash
# Created: 2020-08-31
set -euo pipefail

# The main project redo script controls project lifecycle and workflows.

version="Script.mpe/0.1-alpha"

default_do_include () # Build-Part Target-File Target-Name Temporary
{
  export scriptname=default:include:$2 build_part=$1
  build-ifchange "$build_part"
  shift
  source "$build_part"
}

default_do_main ()
{
  test -e ./.meta/package/envs/main.sh || {
    htd package update && htd package write-scripts
  }
  ENV_NAME=redo . ./.meta/package/envs/main.sh || return
  # XXX: . "${_ENV:="tools/redo/env.sh"}" || return

  # Keep short build sequences in this file (below in the case/easc), but move
  # larger build-scripts to separate files to prevent unnecessary builds from
  # updates to the default.do

  local target="$(echo $REDO_TARGET | tr './' '_')" part
  part=$( lookup_exists $target.do $build_parts_bases ) && {

    default_do_include $part "$@"
    exit $?
  }
  export scriptname=default.do:$1

  case "$1" in

    help )    build-always
              echo "Usage: $package_build_tool [${build_main_targets// /|}]" >&2
      ;;

    # Default build target
    all )     build-always && build $build_all_targets
      ;;


    #test-all) build-always && $component_test $( expand_spec_src units )

    .build/tests/*.tap ) default_do_include \
          "tools/redo/parts/_build_tests_*.tap.do" "$@"
      ;;


    # Integrate other script targets or build other components by name,
    # without additional redo files.
    * ) build-ifchange $components_txt || return
        build_component_exists "$1" && {
          lib_require match &&
          build_component "$@"
          return $?
        } || true

        print_err "error" "" "Unknown target, see '$package_build_tool help'" "$1"
        return 1
      ;;

  esac
}

default_do_main "$@"

# Sync: U-s
# Id: BIN:default.do                                               ex:ft=bash:
