scm_git_pre=SCM.Git
#scm_git_grp=( user-dirs )
scm_git_fun=(
  .at-basedirs
  .git-worktree-status
  #.git-un{tracked,versioned}-files
)
declare -gA \
scm_git_ssc=(
  [.grep-revopt]=\
'  : param ~ "<Expr> <Paths...>"
  git grep "${1:?}" $(git rev-list ${GIT_REVOPT:=--all}) -- "${@:2}"'
  [.status-at]=\
'  local _status_fnmatch=${2:-*} _gitstat
  [[ $# -gt 1 ]] && shift || set -- ${user_basedirs[@]}
  _gitstat=( status -- "$_status_fnmatch" )
  SCM.Git.at-basedirs _gitstat "$@"'
  [.grep-at]=\
'  local _grep_match=${1:?} _grep_fnmatch=${2:-*} _gitgrep
  [[ $# -gt 2 ]] && shift 2 || set -- ${user_basedirs[@]}
  _gitgrep=( grep "$_grep_match" -- "$_grep_fnmatch" )
  SCM.Git.at-basedirs _gitgrep "$@"'
  [git-grep-userdirs]='.grep-at "${@:1:2}" "$user_dirs[@]}" "${@:3}"'
  [git-grep-all-annexes]='.grep-at "${@:1:2}" "$user_annex[@]}" "${@:3}"'
  [git-grep-annex]='.grep-at "${@:1:2}" "${ANNEX_DIR:?}"'
)
declare -gA \
scm_git_als=(
  [git-grep-dirs]='.grep-at'
  [git-status-all]='.status-at'
  [.grep-all-versions]='GIT_REVOPT=--all SCM.Git.grep-revopt'
)
declare -gA \
scm_git_hooks=(
  [define]=\
'User.Config.expand-keymatch-filterhandle  user_annex  basedir.annexes-local  test -d'
  [init]='{
  us_interactive_update+=( scm-git )
  user_config[basedir.annexes-local]="/srv/annex-local/*/"
}'
  [update]='{
  ! GITDIR=$(git rev-parse --git-dir 2>/dev/null) &&
  unset GITDIR || {
    [[ ${GITDIR:0:1} == / ]] && : "$GITDIR" || : "$PWD/$GITDIR"
    GITDIR=$(realpath --relative-to $PWD $_)
    : "./$GITDIR"
    GIT_BASEDIR=${_%/*}

    #declare -gA git_worktree_status
    #SCM.Git.git-worktree-status "$GITDIR" git_worktree_status

    #GIT_ABBREVID=$(git show-ref --head HEAD -s)
    GIT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
    GIT_DESCRIBE=$(git describe --always --dirty --broken)
    [[ ${us_interactive_data["GIT_DESCRIBE"]-} == ${GIT_DESCRIBE} ]] || {
      echo "${_f14}Git at version ${_f2}$GIT_DESCRIBE${NORMAL}"
      us_interactive_data["GIT_DESCRIBE"]=$GIT_DESCRIBE
    }

    #PROMPT_EXTRA=${PROMPT_EXTRA:+$PROMPT_EXTRA │ }
    PROMPT_EXTRA=${PROMPT_EXTRA:+$PROMPT_EXTRA }

    # Use powerline
    #PROMPT_EXTRA+="${_f6}${_f7}$GIT_BRANCH"
    PROMPT_EXTRA+=" $GIT_BRANCH"
    # XXX: U+2387 ALTERNATIVE KEY SYMBOL (too small for use)
    #PROMPT_EXTRA+=" ${_f6}⎇${_f7}$GIT_BRANCH"
    ((PROMPT_MB+=2))
  }
}'
)

SCM.Git.at-basedirs ()
{
  : param '~ <Cmd-arr> <Basedirs...>'
  local -n git_at_cmdargs=${1:?}
  shift
  local bd
  (($#)) && for bd
  do
    [[ -e "$bd/.git" ]] || {
      >&2 echo "Not a Git basedir <$bd>"
      continue
    }
    std_quiet pushd "$bd" || return
    "${QUIET:-false}" ||
      >&2 echo "$bd> $ git [opts] '${git_at_cmdargs[*]}'"
    git "${git_opts[@]}" "${git_at_cmdargs[@]}" || continue
    std_silent popd
  done
}

SCM.Git.git-worktree-status ()
{
  : param '~ <Git-dir> <Out-hash>'
  local -n _scm_git_stat=${2:-git_scm_stat}
      #git rev-parse --verify refs/stash >/dev/null 2>&1 && s="$"
  _scm_git_stat["untracked"]=$(git ls-files --others --dir --git-dir="$1")
  _scm_git_stat["untracked-count"]=$(wc -l <<< "${_scm_git_stat["untracked"]}")
}

# Id: scm-git                                    vim:set ft=bash sw=2 sts=2 et:
