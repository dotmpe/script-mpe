###

##

alias git-v='{ std_V 6 && git_opt=--verbose || {
    std_v 5 && git_opt= || git_opt=--quiet; }; }'


## Global
alias git-aliases="alias | grep '^alias git' | sed 's/^alias git//' && git config --get-regex 'alias.*'"
alias git-authors='git shortlog --summary --email'


## Local

# Basic repo info
alias gitdir='git rev-parse --git-dir'
alias gitpath='git rev-parse --git-path' # ~ <Sub-path>
alias gitbase='git rev-parse --show-toplevel'

alias git-current-branch='git rev-parse --abbrev-ref HEAD'

alias git-staged-q='git diff --quiet --exit-code'
alias git-status-q='git diff-index --cached --quiet --exit-code HEAD --'
alias git-status-q-nsm='git diff-index --ignore-submodules --cached --quiet --exit-code HEAD --'


# List all remote-references for current branch (based on name, not git branch-tracking)
alias git-remote-refs='git for-each-ref "refs/remotes/*/$(git-current-branch)" --format "%(refname)" | cut -d "/" -f3-'
alias git-remote-refs-git='git for-each-ref "refs/remotes/*/$(git-current-branch)" --format "%(refname)"'
# git show-ref does not support fnmatch patterns, for-each-ref does

## List remotes with branch-ref named like current local branch
alias git-remotes='{ git-remote-refs | cut -d "/" -f1; }'


## Commit shortcuts

alias git-commit-m='git commit -m' # ~ <Commit-message>


## Sync

alias git-pull-v='git-v ; git pull ${git_opt:?}'
alias git-push-v='git-v ; git push ${git_opt:?}'
alias git-fetch-v='git-v ; git fetch ${git_opt:?}'


# Tracking config allows for different local/remote name pairings, but this
# is all based on identical names everywhere. See git-remotes.

# Push 'all' means all *branches*, not all remotes! (2)
# With pull it refers to all remotes, but it will not automatigically create
# local heads for each of those. On push it means all branches, so only those
# with local `refs/heads/` get pushed. Right?
alias git-update-clone='git-pull-v --all && git-push-v --all'
#alias git-clone-update-from=

# Actually pull (from the remote ref for current branch at) all remotes (ie.
# only those remotes that have it, as known from the last fetch)
alias git-pull-every='{
  current_branch=$(git-current-branch) && for remote in $(git-remotes);
  do
    case "$(git config remote.$remote.url)" in http* ) continue;; esac;
    git-pull-v $remote $current_branch;
  done; unset remote current_branch;
}'

# Idem. as git-pull-every (for current branch) only now for git-push (again only
# those remotes that already ahd that branch at last fetch)
alias git-push-every='{
  current_branch=$(git-current-branch) && for remote in $(git-remotes);
  do
    case "$(git config remote.$remote.url)" in http* ) continue;; esac;
    git-push-v $remote $current_branch;
  done; unset remote current_branch;
}'

#
