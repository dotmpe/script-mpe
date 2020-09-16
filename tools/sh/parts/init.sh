#!/usr/bin/env bash
#
# Provisioning and project init helpers

usage()
{
  echo 'Usage:'
  echo '  ./tools/sh/parts/init.sh <function name>'
}
abort() { usage && exit 2; } # XXX: see CI/c-bail also


init-git()
{
  test -x "$(which git)" || return
  init-git-hooks || return
  init-git-submodules || return
}

init-git-hooks()
{
  test -e .git/hooks/pre-commit || {
    rm .git/hooks/pre-commit || true
    ln -s ../../tools/git/hooks/pre-commit.sh .git/hooks/pre-commit || return
  }
}

init-git-submodules()
{
  test -e .git/modules || {
    git submodule update --init || return
  }
}

check-git()
{
  test -x "$(which git)" || return
  test -h .git/hooks/pre-commit &&
  test -d .git/modules
}

init-basher()
{
  git clone https://github.com/basherpm/basher.git ~/.basher/
  export PATH=$PATH:$HOME/.basher/bin:$HOME/.basher/cellar/bin
}

check-basher()
{
  basher help >/dev/null
}

init-redo()
{
  basher install apenwarr/redo
}

check-redo()
{
  local r=''
  test -x "$(which redo)" || return
  redo -h 2>/dev/null || r=$?
  test "$r" = "97" || init-err "redo:-h:err:$r"
  # Must not be in parent dir, or targets become mixed with other projects, and harder to track
  # FIXME: only available after run; chicken-and-the-egg problem
  #test -d .redo/ || init-err "redo:repo"
}

init-bats()
{
  $INIT_LOG info "" "Installing bats..."

  : "${BATS_VERSION:=master}"
  : "${BATS_REPO:="https://github.com/bats-core/bats-core.git"}"
  : "${BATS_PREFIX:=$VND_SRC_PREFIX/bats-core/bats-core}"

  test -d $BATS_PREFIX/.git || {

    mkdir -vp "$(dirname "$BATS_PREFIX")"
    test ! -e $BATS_PREFIX || {
      rm -rf $BATS_PREFIX || return
    }

    git clone "$BATS_REPO" $BATS_PREFIX || return $?
  }

  (
    cd $BATS_PREFIX &&
    git checkout "$BATS_VERSION" -- && ./install.sh $PREFIX
  )
}

check-bats()
{
  local bats_version="$(bats --version)" || return
  { test -x "$(which bats)" && fnmatch "Bats 1.1.*" "$bats_version"
  } || {
    $INIT_LOG warn "" "Found $bats_version, getting 1.1..."
    PREFIX=$HOME/.local init-bats || return
  }
}

check-github-release()
{
  github-release --version >/dev/null
}

init-github-release()
{
  go get github.com/aktau/github-release
}

init-git-dep()
{
  test $# -eq 2 || return 98
  test -d "$VND_SRC_PREFIX" -a -w "$VND_SRC_PREFIX" || return 90

  ns_name="$(dirname "$1")"
  test -d "$VND_SRC_PREFIX/$ns_name" || mkdir -p "$VND_SRC_PREFIX/$ns_name"

  # Create clone at path, check for Git dir to not be fooled by any cache/mount
  test -e "$VND_SRC_PREFIX/$1/.git" || {

    test ! -e "$VND_SRC_PREFIX/$1" || rm -rf "$VND_SRC_PREFIX/$1"
    git clone --quiet https://github.com/$1 "$VND_SRC_PREFIX/$1" || return
  }

  ( cd "$VND_SRC_PREFIX/$1" && {
    test -x "${DEBUG:-}" || pwd
    {
      git fetch --quiet "origin" &&
      git fetch --tags --quiet "origin"
    } || {
      $INIT_LOG "error" "$?" "Error retrieving from origin" "$1"
    }
    test -x "${DEBUG:-}" || git show-ref
    git reset --quiet --hard origin/$2 || {
      $INIT_LOG "error" "$?" "Error resetting to $2" "$1"
    }
  } )
}

init-basher-dep() # Repo Version-Ref
{
  test $# -ge 1 -a $# -le 2 || return 98
  test -z "${2:-}" && {

    basher install "$1" || return
  } || {

    BASHER_FULL_CLONE=true basher install "$1" || return
    (
      cd $(basher package-path "$1") && git reset --quiet --hard origin/$2
    )
  }
}

init-deps()
{
  test -d "$VND_SRC_PREFIX" -a -w "$VND_SRC_PREFIX" || return 90

  test $# -eq 1 || set -- dependencies.txt

  grep -v '^\s*\(#.*\|\s*\)$' "$1" |
      sed 's/\s*\(#.*\)$//g' |
  while read installer supportlib version
  do
    $INIT_LOG "info" "" "Checking $installer $supportlib..." "$version"

    : "${version:="master"}"
    init-$installer-dep $supportlib $version

    $INIT_LOG "note" "" "Checked $installer $supportlib..." "$version"
  done
}

init-symlinks()
{
  test -d "$VND_SRC_PREFIX" -a -w "$VND_SRC_PREFIX" &&
    $INIT_LOG note ci:install "Using Github vendor dir" "$VND_SRC_PREFIX" ||
    $INIT_LOG error ci:install "Writable Github vendor dir expected" "$VND_SRC_PREFIX" 1

  # Give private user-script repoo its place
  # TODO: test user-scripts instead/also +U_s +script_mpe
  test -d $HOME/bin/.git || {
    test "$USER" = "travis" || return 100

    rm -rf $HOME/bin || true
    ln -s $HOME/build/dotmpe/script-mpe $HOME/bin
  }
}


init-err()
{
  $INIT_LOG error "" "failed during init" "$*"
  print_red "sh:init" "failed at '$*'" >&2
  exit 1
}


# Groups

check()
{
  default >/dev/null || init-err default

  git describe >/dev/null ||
    init-err "git describe: CWD should be GIT checkout and have tags in repo"
}

default()
{
  check-git || init-err default:$_
  check-basher || init-err default:$_
  check-bats || init-err default:$_
  # XXX: check-redo || init-err redo
  check-github-release || init-err $_
  test -n "$VND_SRC_PREFIX" || init-err $_
  for helper in bats-assert bats-file bats-support
  do
    test -d $VND_SRC_PREFIX/ztombol/$helper || init-err $helper
  done
}

all()
{
  init-git || init-err $_ $?

  # XXX which github-release >/dev/null || {
  test -x "$(which github-release)" || {
    init-github-release || init-err init:all:$_ $?
  }
  test -x "$(which basher)" || {
    init-basher || init-err init:all:$_ $?
  }
  test -x "$(which redo)" || {
    init-redo || init-err init:all:$_ $?
  }

  check-bats || {
    init-bats || init-err init:all:$_ $?
  }
}


# Main

case "$(basename -- "$0" .sh)" in
  -* ) ;; # No main regardless

  init )
      test "$(basename "$(dirname "$0")")/$(basename "$0")" = parts/init.sh ||
        exit 105 # Sanity

      set -euo pipefail
      : "${CWD:="$PWD"}"
      . "$CWD/tools/sh/parts/env-0-1-lib-sys.sh"
      . "$CWD/tools/sh/parts/env-0-src.sh"
      . "$CWD/tools/sh/parts/env-0.sh"
      # XXX: . "${ci_tools:="$CWD/tools/ci"}/env.sh"

      "$@"
    ;;
esac

# Sync: U-S:
