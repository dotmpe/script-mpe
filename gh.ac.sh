#!/usr/bin/env bash
### Auto-compile and source AC for github CLI, update once command file changes
true "${SHELL_NAME:=$(basename "${SHELL/-}")}"
true "${GH_BIN:=$(command -v gh)}"
true "${GH_AC_SH:="${PROJECT_CACHE:-.meta/cache}/gh.ac.sh"}"
{
  test -e "$_" -a "$GH_BIN" -nt "$_"
} || {
  gh completion -s ${SHELL_NAME:?} >| "$_"
}
. "${GH_AC_SH:?}"
