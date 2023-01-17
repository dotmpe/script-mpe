#!/usr/bin/env bash
### Auto-compile and source AC for github CLI, update once command file changes
true "${SHELL_NAME:=$(basename "${SHELL/-}")}"
true "${US_BIN:=$HOME/bin}"
true "${GH_BIN:=$(command -v gh)}"
# Ignore if gh is not installed
test -z "$GH_BIN" || {
  true "${GH_AC_SH:="${PROJECT_CACHE:-.meta/cache}/gh.ac.sh"}"
  {
    test -e "$US_BIN/$_" -a "$GH_BIN" -nt "$US_BIN/$_"
  } || {
    gh completion -s ${SHELL_NAME:?} >| "$_"
  }
  . "$US_BIN/${GH_AC_SH:?}"
}
