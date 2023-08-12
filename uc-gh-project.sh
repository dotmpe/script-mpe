#!/usr/bin/env bash

# Simple expand for args, use one at each line appending it to command
test_args () { # ~ <Command-words> <Args...>
  local x cmd="${1:-test -e}"
  test 2 -le $# || return 3
  shift
  for x in $*; do $cmd "$x" || return; done; }


checkout ()
{
  local repopath=${1:?}
  shift
  projname=${repopath##*/}
  org=${repopath%/*}

  test_args "test -e" /src/vendor/*/$repopath || {
    org=${repopath#/*}
    mkdir -vp /src/vendor/github.com/$org &&
    git clone https://github.com/$repopath /src/vendor/github.com/$repopath ||
      return
  }

  test ! -e "$PROJECT_DIR/$projname/" && {
    test -e /src/vendor/github.com/$repopath &&
    ln -s /src/vendor/github.com/$repopath "$PROJECT_DIR/$projname" ||
      $LOG warn : "FIXME: cannot symlink" "$_" 1
  } ||
    test -d "$PROJECT_DIR/$projname/" &&
    test -h "$PROJECT_DIR/$projname" ||
      $LOG warn : "FIXME: expected symlinked project dir" "$_" 1
}

## Shell mode
set -euo pipefail

## Main script
: "${PROJECT_DIR:=$HOME/project}"

"$@"
