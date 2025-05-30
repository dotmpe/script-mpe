#require

script_mpe_part_als_git_load ()
{
  : source script-mpe:tool/sh/part/als-git.sh
  . "${US_BIN:?}"/tool/sh/part/fun-git.sh
}

git_als ()
{
  : source script-mpe:tool/sh/part/als-git.sh
}


# Change levels with bool chatty.
# If git-chatty is true, then git --verbose is set for v=6, else v=7.
# Otherwise, --quiet is added for either v=5 or v=6 based on git-chatty pref.
alias git-v='{
  {
    ${git_chatty:-true} && not stdlog_quiet 6 || not stdlog_quiet 7;
  } && git_opt=--verbose || {
    { ${git_chatty:-true} && not stdlog_quiet 5 || not stdlog_quiet 6; } && {
      git_opt=
    } || {
      git_opt=--quiet
    }
  };
}'
# Normally WARN/4 is quiet, NOTICE/5 normal and INFO/6 is verbose. For specific
# applications output threshold can be raised one (--verbose is 7/DEBUG and
# 5/NOTICE is --quiet) so that scripts can use NOTICE for specific LOG output
# while keep GIT quiet, by setting git_chatty=false


alias git-sh-aliases="alias | grep -Po '^alias \Kgit.*$' && git config --get-regex 'alias.*'"


## Info - generic

# Basic repo info (local)
alias :git:info:authors='git shortlog --summary --email'
alias :git:info:base='git rev-parse --show-toplevel'
alias git-clean-q='git diff --quiet --exit-code' # No changed files
alias git-clean-nsm-q='git diff --ignore-submodules --quiet --exit-code' # No changed files
alias :git:committed-q='git diff-index --cached --quiet --exit-code HEAD --' # No staged changes
alias :git:committed-nsm-q='git diff-index --ignore-submodules --cached --quiet --exit-code HEAD --'
alias :git:info:branch='git rev-parse --abbrev-ref HEAD'
alias :git:info:status=git\ status
alias :git:info:dir='git rev-parse --git-dir'
alias :git:list:ignored='git ls-files --ignored --exclude-standard'
alias :git:list:untracked='git ls-files --others --exclude-standard'
alias :git:local:spec:ignored=':git:ignore:listspecs'
alias :git:show:path='git rev-parse --git-path' # ~ <Sub-path>

# Ignore (local + global)
git_ignore_specfiles ()
{
  local -n __list=${1:-git_ignore_files}
  if_ok "$(git config --global core.excludesfile)" &&
  test -n "$_" && test -s "$_" && __list+=( "$_" )
  ! test -s ".gitignore" || __list+=( "$_" )
  ! test -s ".git/info/exclude" || __list+=( "$_" )
}
git_ignore_listspecs ()
{
  local -a files
  git_ignore_specfiles files
  cat "${files[@]}"
}
git_ignore_listfiles ()
{
  local -a files
  git_ignore_specfiles files
  local fn
  for fn in "${files[@]}"
  do echo "$fn"
  done
}
alias :git:ignore:list-files=git_ignore_listfiles
alias :git:ignore:list-specs=git_ignore_listspecs

# Info (global)
alias :git:status:all=git_status_all
alias :git:status=:git:status:all


# TODO: these are not repos
git_status_user_dirs () # ~ <Git-status-args> [-- <Basedirs>]
{
  case " $* " in *" -- "* ) ;;
  * ) set -- "$@" -- ~/{Documents,Desktop,Videos,Music,Pictures}
  esac
  git_status_all "$@"
}
alias :git:status:user=git_status_user_dirs

git_status_annex_local () # ~ <Git-status-args> [-- <Basedirs>]
{
  case " $* " in *" -- "* ) ;;
  * ) set -- "$@" -- /srv/annex-*/*/
  esac
  git_status_all "$@"
}
alias :git:status:annex=git_status_annex_local

git_status_user_pack () # ~ <Git-status-args> [-- <Basedirs>]
{
  case " $* " in *" -- "* ) ;;
  * ) set -- "$@" -- \
    ~/{.conf,bin,.l/c,htdocs,project/{user-conf,user-scripts{,-incubator}}}
  esac
  git_status_all "$@"
}
alias :git:status:user=git_status_user_dirs
alias :git:status:pack=git_status_user_pack


# Remotes

# List all remote-references for current branch (based on name, not git branch-tracking)
alias :git:remote-refs='git for-each-ref "refs/remotes/*/$(:git:info:branch)" --format "%(refname)" | cut -d "/" -f3-'
alias :git:remote-refs-git='git for-each-ref "refs/remotes/*/$(:git:info:branch)" --format "%(refname)"'
# git show-ref does not support fnmatch patterns, for-each-ref does

## List remotes with branch-ref named like current local branch
alias :git:remotes='{ :git:remote-refs | cut -d "/" -f1; }'


### Grepping (global)

alias :git:grep:all=git_grep_all

git_grep_user_dirs () # ~ <Git-grep-args> [-- <Basedirs>]
{
  case " $* " in *" -- "* ) ;;
  * ) set -- "$@" -- \
    ~/{Documents,Desktop,Videos,Music,Pictures}
  esac
  git_grep_all "$@"
}
alias :git:grep:user=git_grep_user_dirs

git_grep_user_pack () # ~ <Git-grep-args> [-- <Basedirs>]
{
  case " $* " in *" -- "* ) ;;
  * ) set -- "$@" -- \
    ~/{.conf,bin,.l/c,htdocs,project/{user-conf,user-scripts{,-incubator}}}
  esac
  git_grep_all "$@"
}
alias :git:grep:pack=git_grep_user_pack

alias :git:grep:versions=git_grep_versions

## Grepping (local)
alias :git:tree:grep=git\ grep
alias :git:local:grep=git\ grep


## Sync

alias :git:pull:v='git-v ; git pull ${git_opt?}'
alias :git:push:v='git-v ; git push ${git_opt?}'
alias :git:fetch:v='git-v ; git fetch ${git_opt?}'

alias :git:push=git\ push
alias :git:pull=git\ pull


# Tracking config allows for different local/remote name pairings, but this
# is all based on identical names everywhere. See :git:remotes.

# Push 'all' means all *branches*, not all remotes! (2)
# With pull it refers to all remotes, but it will not automatigically create
# local heads for each of those. On push it means all branches, so only those
# with local `refs/heads/` get pushed. Right?
alias git-update-clone=':git:pull:v --all && :git:push:v --all'
#alias git-clone-update-from=

# Actually pull (from the remote ref for current branch at) all remotes (ie.
# only those remotes that have it, as known from the last fetch)
alias :git:pull:every='{
  g=$(:git:info:dir) ||
    $LOG error : "No GIT dir" E$? $?
  test ! -e $g/MERGE_HEAD && {
    current_branch=$(:git:info:branch) && for remote in $(:git:remotes);
    do
      test ! -e $g/MERGE_HEAD || {
        $LOG warn : "Fix merge first" "" 1
        break
      }
      case "$(git config remote.$remote.url)" in http* ) continue;; esac;
      :git:pull:v $remote $current_branch;
    done; unset remote current_branch;
  } || {
    $LOG warn : "Fix merge first" "" 1
  }
}'

# Idem. as :git:pull:every (for current branch) only now for git-push (again only
# those remotes that already ahd that branch at last fetch)
alias :git:push:every='{
  g=$(:git:info:dir) ||
    $LOG error : "No GIT dir" E$? $?
  test ! -e $g/MERGE_HEAD && {
    current_branch=$(:git:info:branch) && for remote in $(:git:remotes);
    do
      case "$(git config remote.$remote.url)" in http* ) continue;; esac;
      :git:push:v $remote $current_branch;
    done; unset remote current_branch;

  } || {
    $LOG warn : "Fix merge first" "" 1
  }
}'

alias :git:commit-message='$EDITOR "$(git rev-parse --git-path COMMIT_EDITMSG)"'


## Commit shortcuts

alias :git:commit-m='git commit -m' # ~ <Commit-message>
alias :git:commit-now-no-comment='git commit -m "-"'
alias :git:commit-now-accum-comment='git commit -m "Accumulated at $hostname"'
alias :git:ci:nc=:git:commit-now-no-comment
alias :git:ci:now=:git:commit-now-accum-comment


## Short-form aliases (shell)

# XXX: remove vc command first alias vc=:git:commit-message

alias :gcA='git add -u && :gcn'
alias :gca='git commit --amend'
alias :gCa=:gcan
alias :gcan=':gca --no-edit'
alias :gcm=':git:commit-message'
alias :gcN=':git:ci:nc'
alias :gcn=':git:ci:now'
alias :gcp=':git:ci:now && :git:push:every'
alias :gG=:git:tree:grep
alias :ggG=:git:grep:pack
alias :gGa=:git:grep:all
alias :gGp=:git:grep:pack
alias :gGu=:git:grep:user
alias :gl=':git:list-files'
alias :gli=':git:list:ignored'
alias :glI=':git:ignore:list-specs'
alias :gLI=':git:ignore:list-files'
alias :glu=':git:list:unknown'
alias :glU=':git:list:untracked'
alias :gP=:git:pull
alias :gp=:git:push
alias :gs=:git:sync
alias :gS=:git:info:status
alias :gSp=:git:status:pack
alias :gSu=:git:status:user

alias :gpa=:git:pull:every

alias :gPa=:git:push:every

## Synchronize local branch from and to remotes with this branch.
# No new branches are synced.
# XXX: initial git-sync. May want more fancy per-project.
alias :git:sync=':git:fetch:v --all && :gpa && :gPa'

alias :git:update=':git:fetch:v --all && :gpa'

# XXX: also want to update clones, maybe work in bare repos for this?
alias :git:update-all-clones=
#alias git-publish='{
#}'
# NOTE: combined clone-update+publish will make every remote an effective clone of every other.
# This is hardly desired behaviour, and better aliased on a per-project level.



# ex:ft=bash:
