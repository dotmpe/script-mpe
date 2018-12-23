#!/bin/ash
ci_env_=$_

# Boilerplate env for CI scripts


# XXX: Map to namespace to avoid overlap with builtin names
req_subcmd() # Alt-Prefix [Arg]
{
  test $# -gt 0 -a $# -lt 3 || return
  local dflt= altpref="$1" subcmd="$2"

  prefid="$(printf -- "$altpref" | tr -sc 'A-Za-z0-9_' '_')"

  type "$subcmd" 2>/dev/null >&2 && {
    eval ${prefid}subcmd=$subcmd
    return
  }
  test -n "$altpref" || return

  subcmd="$altpref$subcmd"
  type "$subcmd" 2>/dev/null >&2 && {
    eval ${prefid}subcmd=$subcmd
    return
  }

  $LOG error "ci:env" "No subcmd for '$2'"
  return 1
}

req_usage_fail()
{
  type "usage-fail" 2>/dev/null >&2 || {
    $LOG "error" "" "Expected usage-fail in $0" "" 3
    return 3
  }
}

main_() # [Base] [Cmd-Args...]
{
  export TEST_ENV package_build_tool

  local main_ret= base="$1" ; shift 1
  test -n "$base" || base="$(basename "$0" .sh)"

  test $# -gt 0 || set -- default
  req_usage_fail || return
  req_subcmd "$base-" "$1" || usage-fail "$base: $*"

  shift 1
  eval \$${prefid}subcmd "$@" || main_ret=$?
  unset ${prefid}subcmd prefid

  return $main_ret
}

main_test_() # Test-Cat [Cmd-Args...]
{
  export TEST_ENV package_build_tool

  local main_test_ret= testcat="$1" ; shift 1
  test -n "$testcat" || testcat=$(basename "$0" .sh)

  test $# -gt 0 || set -- all
  req_usage_fail || return
  req_subcmd "$testcat-" "$1" || usage-fail "test: $testcat: $*"

  shift 1
  eval \$${prefid}subcmd \"\$@\" || main_test_ret=$?
  unset ${prefid}subcmd prefid

  test -z "$main_test_ret" && print_green "" "OK" || {
    print_red "" "Not OK"
    return $main_test_ret
  }
}


set -e
#set -o pipefail
#set -o nounset

test -x "$(which gdate)" && export gdate=gdate || export gdate=date

export ci_env_ts=$($gdate +"%s.%N")

# Travis env:
# TRAVIS_TIMER_ID=(hex)
# TRAVIS_TIMER_START_TIME=1544134348250991906
#                         1544136294. ie. split at end-9
# TRAVIS_TEST_RESULT=(0|...)
# TRAVIS_COMMIT
# TRAVIS_LANGUAGE=(python|...)
# TRAVIS_INFRA=(gce|...)
# TRAVIS_DIST=(trusty|...)
# TRAVIS_BUILD_STAGE_NAME=?
# TRAVIS_PULL_REQUEST=(true|false)
# TRAVIS_STACK_TIMESTAMP=(ISO DATETIME)
# TRAVIS_JOB_WEB_URL=https://travis-ci.org/bvberkum/script-mpe/jobs/$TRAVIS_JOB_ID
# TRAVIS_BUILD_WEB_URL=https://travis-ci.org/bvberkum/script-mpe/builds/$TRAVIS_BUILD_ID
# TRAVIS_BUILD_NUMBER=[1-9][0-9]*
# TRAVIS_JOB_NUMBER=$BUILD_NUMBER.[1-9][0-9]*
# TRAVIS_BUILD_ID=[1-0][0-9]*
# TRAVIS_JOB_ID=[1-0][0-9]*

export scriptpath=$PWD
export SCRIPTPATH=$PWD/commands:$PWD/contexts:$PWD:$HOME/build/bvberkum/user-scripts/src/sh/lib
export LOG=$PWD/tools/sh/log.sh
export MKDOC_BRANCH=devel

case "$TRAVIS_COMMIT_MESSAGE" in

  *"[clear cache]"* | *"[cache clear]"* )

        test -e .htd/travis.json && {

          rm -rf  $(jq -r '.cache.directories[]' .htd/travis.json)

        } || {
          rm -rf \
               ./node_modules \
               ./vendor \
               $HOME/.local \
               $HOME/.basher \
               $HOME/.cache/pip \
               $HOME/virtualenv \
               $HOME/.npm \
               $HOME/.composer \
               $HOME/.rvm/ \
               $HOME/.statusdir/ \
               $HOME/build/apenwarr \
               $HOME/build/ztombol \
               $HOME/build/bvberkum/user-scripts \
               $HOME/build/bvberkum/user-conf \
               $HOME/build/bvberkum/docopt-mpe \
               $HOME/build/bvberkum/git-versioning \
               $HOME/build/bvberkum/bats-core || true
        }
    ;;
esac

{
  test "$SHIPPABLE" = true || {
    python -c 'import sys;
if not hasattr(sys, "real_prefix"): sys.exit(1)'
  }
} && {

  $LOG info "tools/ci/env" "Using existing Python virtualenv"

} || {
  test -d ~/.pyvenv/htd || virtualenv ~/.pyvenv/htd
  . ~/.pyvenv/htd/bin/activate || {
    $LOG error "tools/ci/env" "Error in Py venv setup ($?)" "" 1
  }
}

# FIXME: need this too early during prototyping, see ci/parts/init
test -d "$HOME/build/bvberkum/user-scripts" && {
  ( cd "$HOME/build/bvberkum/user-scripts" && git fetch --all &&
      git reset --hard origin/r0.0 )
} || {
  git clone https://github.com/bvberkum/user-scripts $HOME/build/bvberkum/user-scripts
  ( cd "$HOME/build/bvberkum/user-scripts" && git checkout -t origin/r0.0 -b r0.0 )
}


$LOG info tools/ci/env "Loading shell util"
util_mode=boot . $scriptpath/util.sh
unset util_mode
std_info "std env loaded"


shell_init || error "Failure in shell-init" 1

test -n "$IS_BASH" || error "Need to know shell dist" 1
#. ./tools/sh/init.sh &&
lib_load build-htd projectenv env-deps web
test 0 -eq $IS_BASH_SH && {
   export SCR_SYS_SH=sh || export SCR_SYS_SH=bash-sh
} || true

sh_env_ts=$($gdate +"%s.%N")
. ./tools/sh/env.sh


ci_env_end_ts=$($gdate +"%s.%N")
note "CI Env pre-load time: $(echo "$sh_env_ts - $ci_env_ts"|bc) seconds"
note "Sh Env load time: $(echo "$ci_env_end_ts - $ci_env_ts"|bc) seconds"

# Id: script-mpe/0.0.4-dev tools/ci/env.sh
