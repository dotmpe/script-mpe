#!/usr/bin/env bash

## Auto-compile and source AC script for github CLI, update on changes

# Auto-completion is loaded automatically for shells in interactive mode,
# see in bash-ac group and uconf:profile.tab.
# Initializes when sourced in shell and gh executable is available.

true "${SHELL_NAME:=$(basename "${SHELL/-}")}"
true "${US_BIN:=$HOME/bin}"
true "${GH_BIN:=$(command -v gh)}"
# Ignore if gh is not installed
test -z "$GH_BIN" || {
  ! "${UC_DEBUG:-false}" ||
    $LOG warn :gh.ac.sh "Loading..." "gh-ac-sh=${GH_AC_SH:="$US_BIN/${PROJECT_CACHE:-.meta/cache}/gh.ac.sh"}"
  true "${GH_AC_SH:="$US_BIN/${PROJECT_CACHE:-.meta/cache}/gh.ac.sh"}"
  {
    test -e "$_" -a "$GH_BIN" -ot "$_"
  } || {
    gh completion -s ${SHELL_NAME:?} >| "$_"
  }
  . "${GH_AC_SH:?}"
}
