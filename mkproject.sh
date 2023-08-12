#!/usr/bin/env bash

## Shell mode
set -euo pipefail

## Helpers
# Pass return status
if_ok () { return; }
# Match against glob
fnmatch () { case "${2:?}" in ${1:?} ) ;; * ) false; esac; }
# Simple expand for args, use one at each line appending it to command
test_args () { # ~ <Command-words> <Args...>
  local x cmd="${1:-test -e}"
  test 2 -le $# || return 3
  shift
  for x in $*; do $cmd "$x" || return; done; }

## Main script
projname=${1:?}
[[ "$projname" =~ ^[a-z_][a-z0-9_\.-]+$ ]] ||
  $LOG error :mkproject "Invalid characters" "$projname" $?
orgname="${HTD_ORG:-${HTD_DOMAIN:-${HTD_GIT_REMOTE:?}}}"
scm=git
: "${PROJECT_DIR:=$HOME/project}"

# XXX: srv-scm is not organized everywhere
{ test ! -e "/srv/scm-$scm/$projname.$scm" &&
  test_args "test ! -e" /src/local/$projname{,+*} &&
  test ! -e "/src/vendor/*/$orgname/$projname" &&
  test ! -e "${PROJECT_DIR:?}/$projname"
} ||
  $LOG error :mkproject "Alread exists" "$projname" $?

cd "$PROJECT_DIR"

mkdir -v /src/local/$projname+dev+current
ln -vs /src/local/$projname+dev+current $projname

cd $projname

{
  cat <<EOM
${projname^}
${projname//[[:print:]]/=}
:Created: $(date --iso=min)

..
EOM
} > ReadMe.rst

git init && git add ReadMe.rst
