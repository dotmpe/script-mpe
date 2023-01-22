#!/usr/bin/env bash

## Auto-source Jmp framework

# XXX: testing
# Auto-completion is loaded automatically for shells in interactive mode,
# see in bash-ac group and profile.tab from UConf.
# Initializes when sourced in shell and gholmes829/jmp repo exists.

true "${US_BIN:=${HOME:?}/bin}"

true "${SRC:=/src}"
true "${JMP_SRC_DIR:=$SRC/vendor/github.com/gholmes829/Jmp}"

test ! -d "$JMP_SRC_DIR" || {
  true "${JMP_AC_SH:="$US_BIN/${PROJECT_CACHE:-.meta/cache}/jmp.ac.sh"}"
  {
    test -e "$_" -a "$JMP_SRC_DIR/Jmp/jmp_wrapper.sh" -ot "$_"
  } || {
    {
      echo "source \"${JMP_SRC_DIR:?}/jmp_wrapper.sh\""
      echo SCRIPT_DIR="${JMP_SRC_DIR:?}"
    } >| "$_"
  }

  . "${JMP_AC_SH:?}"
}
