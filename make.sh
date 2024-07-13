#!/usr/bin/env bash
#FIXME: !/bin/sh
# Make: frontend to build shell scripts from subcommands without boilerplate
# Created: 2020-06-30

# Template main entry point parts using main-defs.lib, reading
# from template variables listed as main-* blocks after the script body.

# XXX: using a custom preproc reader and directives would be another
#   approach to the same effect. That might be a bit cleaner and more
#   extensible.

set -eu

CWD="$(dirname "$0")"

test ${main_make_lib_load-1} -eq 0 || {
  . $CWD/main-make.lib.sh || exit
  main_make_lib__load
  main_make_lib_load=$?
}

# Parse source script
make_main ()
{
  local make_script make_scriptname make_scriptpath \
      main_aliases
  make_script=$1
  make_scriptname=$(basename "$1" .sh)
  make_scriptpath=$(dirname "$1")
  #local vid; str_vword vid "$make_scriptname"; local base=$vid
  local $make_main_parts

  grep -q '^MAKE-HERE$' "$1" && {
    make_here "$@" || exit $?
  } || {
    make_preproc "$@" || exit $?
  }

  shift
  test ${make_echo-0} -eq 0 || echo
  main_entry "$@"
}

# Start by parsing source script, then call main_make to define real shell
# script.
make_main "$@"
# Id: script-mpe/0.0.4-dev make.sh
