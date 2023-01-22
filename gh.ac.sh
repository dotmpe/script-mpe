#!/usr/bin/env bash

## Auto-compile and source AC script for github CLI, update once command file changes

# Auto-completion is loaded automatically for shells in interactive mode,
# see in bash-ac group and profile.tab from UConf.
# Initializes when sourced in shell and gh executable is available.

true "${SHELL_NAME:=$(basename "${SHELL/-}")}"
true "${US_BIN:=$HOME/bin}"
true "${GH_BIN:=$(command -v gh)}"
# Ignore if gh is not installed
test -z "$GH_BIN" || {
  true "${GH_AC_SH:="$US_BIN/${PROJECT_CACHE:-.meta/cache}/gh.ac.sh"}"
  {
    test -e "$_" -a "$GH_BIN" -ot "$_"
  } || {
    gh completion -s ${SHELL_NAME:?} >| "$_"
  }
  . "${GH_AC_SH:?}"
}
