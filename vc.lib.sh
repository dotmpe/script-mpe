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
  ( cd "$1" && go_to_directory .hg && echo $(pwd)/.hg || return 1 )
}

vc_issvn()
{
  test -e $1/.svn
}

vc_svndir()
{
  ( test -e "$1/.svn" && echo $(pwd)/.svn || return 1 )
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

# NOTE: scanning like this does not allow to nest in different repositories
# except but one in order.
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

vc_unversioned_bzr()
{
  bzr ls --unknown || return $?
}

vc_unversioned_svn()
{
  {
    svn status | grep '^?' | sed 's/^?\ *//g'
  } || return $?
}

vc_untracked_hg()
{
  hg status --unknown | cut -c3-
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

vc_untracked_bzr()
{
  bzr ls --ignored --unknown || return $?
}

vc_untracked_git()
{
  git ls-files --others --dir || return $?
}

vc_untracked_svn()
{
  { svn status --no-ignore || return $?
  } | grep '^?' | sed 's/^?\ *//g'
}

vc_untracked_hg()
{
  hg status --ignored --unknown | cut -c3-
}

vc_untracked()
{
  test -n "$spwd" || error spwd-13 13

  # list paths not under version (including ignores)
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

vc_tracked_git()
{
  git ls-files
}

vc_tracked_bzr()
{
  bzr ls
}

vc_tracked_svn()
{
  { svn list --depth infinity || return $?
  } | grep '^?' | sed 's/^?\ *//g'
}

vc_tracked_hg()
{
  { hg status --clean --modified --added || return $?
  } | cut -c3-
}

vc_tracked()
{
  test -n "$spwd" || error spwd-13 13

  # list paths not under version (including ignores)
  vc_tracked_$scm

  test "$scm" = "git" && {

    vc_git_submodules | while read prefix
    do
      smpath=$ppwd/$prefix
      cd "$smpath"
      ppwd=$smpath spwd=$spwd/$prefix \
        vc_tracked_git \
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
    trueish "$quiet" ||
        note "Submodule '$prefix' ($spwd/$prefix)"
    echo "$prefix"
  done
}

# TODO: maybe rename htd_update_remote
vc_git_update_remote()
{
  local remote_url="$(git config --get remote.$1.url)"
  test -z "$remote_url" && {

    git remote add $1 $2 &&
        note "Remote '$1' added" || warn "Error adding '$1' remote" 1

  } || {

    test "$2" = "$remote_url" || {
      git remote set-url $1 $2 &&
        note "Remote '$1' updated" || warn "Error updating '$1' remote" 1
    }
  }
}


# __vc_git_flags accepts 0 or 1 arguments (i.e., format string)
# returns text to add to bash PS1 prompt (includes branch name)
vc_flags_git()
{
  test -n "$1" || set -- "$(pwd)"
  g="$(vc_gitdir "$1")"
  test -e "$g" || return

  test "$(echo $g/refs/heads/*)" != "$g/refs/heads/*" || {
    echo "(git:unborn)"
    return
  }

  cd $1
  local r
  local b
  if [ -f "$g/rebase-merge/interactive" ]; then
    r="|REBASE-i"
    b="$(cat "$g/rebase-merge/head-name")"
  elif [ -d "$g/rebase-merge" ]; then
    r="|REBASE-m"
    b="$(cat "$g/rebase-merge/head-name")"
  else
    if [ -d "$g/rebase-apply" ]; then
      if [ -f "$g/rebase-apply/rebasing" ]; then
        r="|REBASE"
      elif [ -f "$g/rebase-apply/applying" ]; then
        r="|AM"
      else
        r="|AM/REBASE"
      fi
    elif [ -f "$g/MERGE_HEAD" ]; then
      r="|MERGING"
    elif [ -f "$g/BISECT_LOG" ]; then
      r="|BISECTING"
    fi

    b="$(git symbolic-ref HEAD 2>/dev/null)" || {

      b="$(
      case "${GIT_PS1_DESCRIBE_STYLE-}" in
      (contains)
        git describe --contains HEAD ;;
      (branch)
        git describe --contains --all HEAD ;;
      (describe)
        git describe HEAD ;;
      (* | default)
        git describe --exact-match HEAD ;;
      esac 2>/dev/null)" ||

      b="$(cut -c1-11 "$g/HEAD" 2>/dev/null)" || b="unknown"
      # XXX b="($b)"
    }
  fi

  local w= i= s= u= c=

  if [ "true" = "$(git rev-parse --is-inside-git-dir 2>/dev/null)" ]; then
    if [ "true" = "$(git rev-parse --is-bare-repository 2>/dev/null)" ]; then
      c="BARE:"
    else
      b="GIT_DIR!"
    fi
  elif [ "true" = "$(git rev-parse --is-inside-work-tree 2>/dev/null)" ]; then
    if [ -n "${GIT_PS1_SHOWDIRTYSTATE-}" ]; then

      if [ "$(git config --bool bash.showDirtyState)" != "false" ]; then

        git diff --no-ext-diff --ignore-submodules \
          --quiet --exit-code || w='*'

        if git rev-parse --quiet --verify HEAD >/dev/null; then

          git diff-index --cached --quiet \
            --ignore-submodules HEAD -- || i="+"
        else
          i="#"
        fi
      fi
    fi
    if [ -n "${GIT_PS1_SHOWSTASHSTATE-}" ]; then
      git rev-parse --verify refs/stash >/dev/null 2>&1 && s="$"
    fi

    if [ -n "${GIT_PS1_SHOWUNTRACKEDFILES-}" ]; then
      if [ -n "$(git ls-files --others --exclude-standard)" ]; then
        u="~"
      fi
    fi
  fi

  repotype="$c"
  branch="${b##refs/heads/}"
  modified="$w"
  staged="$i"
  stashed="$s"
  untracked="$u"
  state="$r"

  x=
  rg=$g
  test -f "$g" && {
    g=$(dirname $g)/$(cat .git | cut -d ' ' -f 2)
  }

  # TODO: move to extended escription cmd
  #x="; $(git count-objects -H | sed 's/objects/obj/' )"

  if [ -d $g/annex ]; then
    #x="$x; annex: $(echo $(du -hs $g/annex/objects|cut -f1)))"
    x="$x annex"
  fi

  test -n "${2-}" && fmt="$2" || fmt='(%s%s%s%s%s%s%s%s)'
  printf "$fmt" "$c" "${b##refs/heads/}" "$w" "$i" "$s" "$u" "$r" "$x"

  cd "$cwd"
}

vc_git_annex_list()
{
  git annex list "$@" | grep '^[_X]*\ ' | sed 's/^[_X]*\ //g'
}

vc_stats()
{
  test -n "$1" || set -- "." "$2"
  test -n "$2" || set -- "$1" "  "
  { cat <<EOM
$2status-flags: $(vc_flags_${scm} . "%s%s%s%s%s%s%s%s"  )
$2tracked: $( vc_tracked | count_lines )
$2unversioned: $( vc_unversioned | count_lines )
$2untracked:
$2  cleanable: $( vc ufc | count_lines )
$2  temporary: $( vc uft | count_lines )
$2  uncleanable: $( vc ufu | count_lines )
$2  (total): $( vc_untracked | count_lines )
EOM
  }
  test -d "$1/.$scm/annex" && {
    printf "$2annex:\n"
    printf "$2  files: $( vc_git_annex_list | count_lines )\n"
    printf "$2  here: $( vc_git_annex_list -i here | count_lines )\n"
    printf "$2  unused: $( git annex unused | count_lines )\n"
  }
  printf "$2(date): $( date_microtime )\n"
}
