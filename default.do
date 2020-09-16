#!/usr/bin/env bash
# Created: 2020-08-31
set -euo pipefail

# The main project redo script controls project lifecycle and workflows

version="Script.mpe/0.1-alpha"

default_do_include () # Build-Part Target-File Target-Name Temporary
{
  export scriptname=default:include:$2 build_part=$1
  build-ifchange "$build_part"
  shift
  source "$build_part"
}

default_do_main()
{
  . "${_ENV:="tools/redo/env.sh"}" || return

  # Keep short build sequences in this file (below in the case/easc), but move
  # larger build-scripts to separate files to prevent unnecessary builds from
  # updates to the default.do

  local target="$(echo $REDO_TARGET | tr './' '_')"
  local build_part="tools/$package_build_tool/parts/$target.do"
  test -e "$build_part" && {

    default_do_include $build_part "$@"
    exit $?
  }

  export scriptname=default.do:$1

  case "$1" in
  
    help )    build-always
              echo "Usage: $package_build_tool [help|all|init|check|build|test|pack|dist]" >&2
      ;;

    # Default build target
    all )     echo "Building $1 targets (but stopping before dist)" >&2
              build-always && build init check build test pack
      ;;
  
    init )    build-always && build build:init check
      ;;
  
    check )   build-always && build build:check
      ;;
  
    build )   build-always && build-ifchange build:check build:manual
      ;;
 

    test )    build-always && build test/baselines test/required
      ;;
  

    #test-all) build-always && $component_test $( expand_spec_src units )


    pack )    build-always
      ;;
  
    dist )    build-always
      ;;


    build:* ) # build-ifchange .build.sh && ./.build.sh "$(echo "$1" | cut -c7- )"
      ;;

    .build/tests/*.tap ) default_do_include \
          "tools/redo/parts/_build_tests_*.tap.do" "$@"
      ;;


    * ) print_err "error" "" "Unknown target, see '$package_build_tool help'" "$1"
        return 1
      ;;
  
  esac
}

default_do_main "$@"

# Sync: U-s
# Id: BIN:default.do                                               ex:ft=bash:
