#!/bin/sh

set -e


# See if path is in GIT checkout
vc_isgit()
{
  test -e "$1" || error "vc-isgit expected path argument" 1
  test -d "$1" || {
    set -- "$(dirname "$1")"
  }
  ( cd $1 && go_to_directory .git || return 1 )
}

# __vc_gitdir accepts 0 or 1 arguments (i.e., location)
# echo absolute location of .git repo, return
# be silent otherwise
vc_gitdir()
{
  test -n "$1" || set -- "."
  test -d "$1" || error "vc-gitdir expected dir argument" 1
  test -z "$2" || error "vc-gitdir surplus arguments" 1

  test -d "$1" || {
    set -- "$(dirname "$1")"
  }

  test -d "$1/.git" && {
    echo "$1/.git"
  } || {
    test "$1" = "." || cd $1
    git rev-parse --git-dir 2>/dev/null
  }
}

vc_hgdir()
{
  test -d "$1" || error "vc-hgdir expected dir argument" 1
  ( cd "$1" && go_to_directory .hg && pwd || return 1 )
}

vc_issvn()
{
  test -e $1/.svn
}

vc_svndir()
{
  ( test -e "$1/.svn" && pwd || return 1 )
}

vc_bzrdir()
{
  local cwd="$(pwd)"
  (
    cd "$1"
    root=$(bzr info 2> /dev/null | grep 'branch root')
    if [ -n "$root" ]; then
      echo $root/.bzr | sed 's/^\ *branch\ root:\ //'
    fi
  )
  return 1
}

vc_dir()
{
  test -n "$1" || set -- "."
  vc_gitdir "$1" || {
    vc_bzrdir "$1" || {
      vc_svndir "$1" || {
        vc_hgdir "$1" || return 1
      }
    }
  }
}

vc_isscmdir()
{
  test -n "$1" || set -- "."
  vc_isgit "$1" || {
    vc_isbzr "$1" || {
      vc_issvn "$1" || {
        vc_ishg "$1" || return 1
      }
    }
  }
}

vc_scmdir()
{
  vc_dir "$@" || error "can't find SCM-dir" 1
}

vc_getscm()
{
  scmdir=$(vc_dir "$@")
  test -n "$scmdir" || return 1
  scm=$(basename "$scmdir" | cut -c2-)
}

vc_gitremote()
{
  test -n "$1" || set -- "." "origin"
  test -d "$1" || error "vc-gitremote expected dir argument" 1
  test -n "$2" || error "vc-gitremote expected remote name" 1
  test -z "$3" || error "vc-gitremote surplus arguments" 1

  cd "$(vc_gitdir "$1")"
  git config --get remote.$2.url
}

# Given COPY src and trgt file from user-conf repo,
# see if target path is of a known version for src-path in repo,
# and that its the currently checked out version.
vc_gitdiff()
{
  test -n "$1" || error "vc-gitdiff expected src" 1
  test -n "$2" || error "vc-gitdiff expected trgt" 1
  test -z "$3" || error "vc-gitdiff surplus arguments" 1
  test -n "$GITDIR" || error "vc-gitdiff expected GITDIR env" 1
  test -d "$GITDIR" || error "vc-gitdiff GITDIR env is not a dir" 1

  target_sha1="$(git hash-object "$2")"
  co_path="$(cd $GITDIR;git rev-list --objects --all | grep "^$target_sha1" | cut -d ' ' -f 2)"
  test -n "$co_path" -a "$1" = "$GITDIR/$co_path" && {
    # known state, file can be safely replaced
    test "$target_sha1" = "$(git hash-object "$1")" \
      && return 0 \
      || {
        return 1
      }
  } || {
    return 2
  }
}

vc_unversioned_git()
{
  git ls-files --others --exclude-standard --dir || return $?
}

vc_unversioned()
{
  test -n "$spwd" || error spwd-13 13

  # list paths not in git (including ignores)
  vc_unversioned_$scm

  test "$scm" = "git" && {

    vc_git_submodules | while read prefix
    do
      smpath=$ppwd/$prefix
      cd "$smpath"
      ppwd=$smpath spwd=$spwd/$prefix \
        vc_unversioned \
            | grep -Ev '^\s*(#.*|\s*)$' \
            | sed 's#^#'"$prefix"'/#'
    done
  }

  cd "$ppwd"
}

vc_untracked_git()
{
  git ls-files --others --dir || return $?
}

vc_untracked()
{
  test -n "$spwd" || error spwd-13 13

  # list paths not in git (including ignores)
  vc_untracked_$scm

  test "$scm" = "git" && {

    vc_git_submodules | while read prefix
    do
      smpath=$ppwd/$prefix
      cd "$smpath"
      ppwd=$smpath spwd=$spwd/$prefix \
        vc_untracked \
            | grep -Ev '^\s*(#.*|\s*)$' \
            | sed 's#^#'"$prefix"'/#'
    done
  }

  cd "$ppwd"
}

vc_clean()
{
  (
    trueish "$1" && { vc_unversioned
    } || { vc_untracked
    }
  )
}

vc_git_submodules()
{
  git submodule foreach | sed "s/.*'\(.*\)'.*/\1/" | while read prefix
  do
    smpath=$ppwd/$prefix
    test -e $smpath/.git || {
      warn "Not a submodule checkout '$prefix' ($spwd/$prefix)"
      continue
    }
    note "Submodule '$prefix' ($spwd/$prefix)"
    echo "$prefix"
  done
  #git submodule | cut -d ' ' -f 2
}
