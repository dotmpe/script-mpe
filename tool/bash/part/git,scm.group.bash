scm_git_pre=SCM.Git
#scm_git_grp=( user-dirs )
scm_git_man='scm-git - Better user commands for Git

See git.* aliases for initial common use. Work in progress.

  git.grep.all            # .grep-all
  git.grep.dirs           # .grep-at
  git.grep.versions       # .grep-version
  git.status.all          # .status-all
'
scm_git_fun=(
  .at-basedirs
  .worktree-status
  .grep-all
  .status-all
  .grep-version
  .period
  .remotes
  .remotes-byname
  # TODO: .un{tracked,versioned}-files
)

declare -gA \
scm_git_ssc=(
  [.grep-revopt]=\
'  : param ~ "<Expr> <Paths...>"
  git grep "${1:?}" $(git rev-list ${GIT_REVOPT:=--all}) -- "${@:2}"'

  [.describe-at]=\
': param '\''~ <Base-dirs...>'\''
  local _gitdescribe
  (($#)) || set -- ${user_basedirs[@]}
  _gitdescribe=( describe --always --dirty --broken )
  SCM.Git.at-basedirs _gitdescribe "$@"'

  [.sync-at]=\
': param '\''~ <Base-dirs...>'\''
  local _gitsync
  (($#)) || set -- ${user_basedirs[@]}
  _gitsync=( sync --soft )
  SCM.Git.at-basedirs _gitsync "$@"'

  [.status-at]=\
': param '\''~ <File-match-> <Base-dirs...>'\''
  local _status_fnmatch=${1:-*} _gitstat
  [[ $# -gt 1 ]] && shift || set -- ${user_basedirs[@]}
  _gitstat=( status --short --untracked-files=no -- "$_status_fnmatch" )
  SCM.Git.at-basedirs _gitstat "$@"'

  [.grep-at]=\
'  local _grep_match=${1:?} _grep_fnmatch=${2:-*} _gitgrep
  [[ $# -gt 2 ]] && shift 2 || set -- ${user_basedirs[@]}
  _gitgrep=( grep "$_grep_match" -- "$_grep_fnmatch" )
  SCM.Git.at-basedirs _gitgrep "$@"'

  [.grep-userdirs]='.grep-at "${@:1:2}" "$user_dirs[@]}" "${@:3}"'
  [.grep-all-annexes]='.grep-at "${@:1:2}" "$user_annex[@]}" "${@:3}"'
  [.grep-annex]='.grep-at "${@:1:2}" "${ANNEX_DIR:?}"'
  [.info]='{
  git submodule && find . -iname .git -not -path "./.git/*"
  [[ ! -d .git/annex/objects ]] ||
    du -hs .git/annex/objects
}'

  [.glob-insensitive]='{
  User-Script.String.case-insensitive-glob _git_ls "$1" &&
  git ls-files "*$_git_ls*"
}'
  [.ls-insensitive]='{
  User-Script.String.case-insensitive-glob _git_ls "$1" &&
  git ls-files "$_git_ls"
}'

#  [.update]='.fetch-v --all && :gpa'
)
declare -gA \
scm_git_als=(

  [.grep-all-versions]='GIT_REVOPT=--all SCM.Git.grep-revopt'
  # XXX: also want to update clones, maybe work in bare repos for this?
  #[.update-all-clones]=

  # XXX: not sure yet about how to build alt namespace or trees
  [git.grep.all]=.grep-all
  [git.grep.dirs]=.grep-at
  [git.grep.versions]=.grep-version
  [git.status.all]=.status-all
  [git.status.at]=.status-at

  [scm.git.help]='echo "$scm_git_man"'
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
  #! GITDIR=$(2>/dev/null git rev-parse --git-dir) &&

  ! GIT_BASEDIR=$(2>/dev/null git rev-parse --show-toplevel) &&
  unset GIT_BASEDIR || {
    #[[ ${GIT_BASEDIR:0:1} == / ]] && : "$GIT_BASEDIR" || : "$PWD/$GIT_BASEDIR"
    #GIT_BASEDIR=$(realpath --relative-to $PWD $_)

    declare -gA git_worktree_status
    SCM.Git.worktree-status "$GIT_BASEDIR" git_worktree_status

    #GIT_ABBREVID=$(git show-ref --head HEAD -s)
    GIT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
    GIT_DESCRIBE=$(git describe --always --dirty --broken)
    [[ ${us_interactive_data["GIT_DESCRIBE"]-} == ${GIT_DESCRIBE} ]] || {
      echo "${_f14-}Git at version ${_f2-}$GIT_DESCRIBE${NORMAL}"
      us_interactive_data["GIT_DESCRIBE"]=$GIT_DESCRIBE
    }

    PROMPT_EXTRA=${PROMPT_EXTRA:+$PROMPT_EXTRA }

    [[ $TERM == linux* ]] &&
    PROMPT_EXTRA+="# $GIT_BRANCH" || {
      # Use powerline
      #PROMPT_EXTRA+="${_f6-}${_f7-}$GIT_BRANCH"
      PROMPT_EXTRA+=" $GIT_BRANCH"
      ((PROMPT_MB+=2))
    }

    [[ ${git_worktree_status["modified-count"]} -eq 0 ]] ||
      PROMPT_EXTRA+=" *${git_worktree_status["modified-count"]}"
    [[ ${git_worktree_status["added-count"]} -eq 0 ]] ||
      PROMPT_EXTRA+=" +${git_worktree_status["added-count"]}"
    [[ ${git_worktree_status["deleted-count"]} -eq 0 ]] ||
      PROMPT_EXTRA+=" -${git_worktree_status["deleted-count"]}"
    [[ ${git_worktree_status["untracked-count"]} -eq 0 ]] ||
      PROMPT_EXTRA+=" ~${git_worktree_status["untracked-count"]}"
  }
}'
)

SCM.Git.at-basedirs ()
{
: param '~ <Cmd-arr> <Basedirs...>'
  local -n git_at_cmdargs=${1:?}
  shift
  (($#)) || return ${_E_GAE:?}
  local bd
  for bd
  do
    [[ -e "$bd/.git" ]] || {
      >&2 echo "Not a Git basedir <$bd>"
      continue
    }
    std_quiet pushd "$bd" || return
    "${QUIET:-false}" ||
      >&2 echo "$bd> $ git [opts] '${git_at_cmdargs[*]}'"
    git "${git_opts[@]}" "${git_at_cmdargs[@]}" || continue
    std_quiet popd
  done
}

SCM.Git.worktree-status ()
{
: param '~ <Git-dir> <Out-hash>'
  local -n _scm_git_stat=${2:-git_scm_stat}
  #git rev-parse --verify refs/stash >/dev/null 2>&1 && s="$"

  _scm_git_stat["added"]=$(cd "$1" && git diff --cached --name-only --diff-filter=A)
  [[ ${_scm_git_stat["added"]:+set} ]] &&
  _scm_git_stat["added-count"]=$(wc -l <<< "${_scm_git_stat["added"]}") ||
  _scm_git_stat["added-count"]=0

  _scm_git_stat["deleted"]=$(cd "$1" && git ls-files --deleted)
  [[ ${_scm_git_stat["deleted"]:+set} ]] &&
  _scm_git_stat["deleted-count"]=$(wc -l <<< "${_scm_git_stat["deleted"]}") ||
  _scm_git_stat["deleted-count"]=0

  _scm_git_stat["modified"]=$(cd "$1" && git ls-files --modified)
  [[ ${_scm_git_stat["modified"]:+set} ]] &&
  _scm_git_stat["modified-count"]=$(wc -l <<< "${_scm_git_stat["modified"]}") ||
  _scm_git_stat["modified-count"]=0

  _scm_git_stat["untracked"]=$(cd "$1" && git ls-files --others --dir --exclude-standard)
  [[ ${_scm_git_stat["untracked"]:+set} ]] &&
  _scm_git_stat["untracked-count"]=$(wc -l <<< "${_scm_git_stat["untracked"]}") ||
  _scm_git_stat["untracked-count"]=0
}

# XXX: cleanup
#git_fun ()
#{
#  wrap_seq__basedirs_with_app_opts git grep \"\$@\"
#}

# TODO: provide function part for git-grep.sh functionality
SCM.Git.grep-all () # ~ <Git-grep-args> [-- <Basedirs>]
{
  local -a git_grep_args
  while [[ $# -gt 0 && $1 != -- ]]
  do
    git_grep_args+=( "$1" )
    shift
  done
  [[ ${#git_grep_args[@]} -gt 0 ]] ||
    _ERR "Grep expression expected" || return
  shift
  [[ ${#} -gt 0 ]] || {
    local -a _basedirs
    #read -r -a _basedirs <<< "${PATH//:/ }"
    mapfile -t _basedirs <<< "${PATH//:/$'\n'}"
    set -- "${_basedirs[@]}"
  }
  [[ ${#} -gt 0 ]] ||
    _ERR "Basedirs expected" || return
  _IFVBS _WARN "Grepping ${#} dirs..."
  for tp
  do
    [[ -e ${tp}/.git ]] || {
      _IFVBS _WARN "Not a repository: $tp"
      continue
    }
    std_quiet pushd "$tp" || return
    "${QUIET:-false}" ||
      stderr echo "$tp> $ git grep '${git_grep_args[*]}'"
    git "${git_args[@]}" grep "${git_grep_args[@]}"
    std_quiet popd
  done
}

SCM.Git.status-all () # ~ <Git-status-args> [-- <Basedirs>]
{
: about 'Get detailed file status for worktrees at basedirs'
: extended 'Set SCM_GIT_PATH to specify default basedirs (fallback is PATH)'
  local -a git_status_args
  while [[ $# -gt 0 && $1 != -- ]]
  do
    git_status_args+=( "$1" )
    shift
  done
  shift
  [[ ${#} -gt 0 ]] || {
    # Use paths from ENV as basedirs
    local _pathlookup=${SCM_GIT_PATH:-${PATH}}
    local -a _basedirs
    mapfile -t _basedirs <<< "${_pathlookup//:/$'\n'}"
    set -- "${_basedirs[@]}"
  }
  [[ ${#} -gt 0 ]] ||
    _ERR "Basedirs expected" || return
  _IFVBS _WARN "Tracking ${#} dirs..."
  for tp
  do
    [[ -e ${tp}/.git ]] || {
      _IFVBS _WARN "Not a repository: $tp"
      continue
    }
    std_quiet pushd "$tp" || return
    "${QUIET:-false}" ||
      stderr echo "$tp> $ git status${git_status_args:+" '${git_status_args[*]}'"}"
    git "${git_args[@]}" status "${git_status_args[@]}"
    std_quiet popd
  done
}

SCM.Git.grep-version () # ~ <Expr> <Paths...>
{
  git grep "${1:?}" $(git rev-list ${GIT_REVOPT:=--all}) -- "${@:2}"
}

SCM.Git.period ()
{
  : about 'Output lines with first/last commit dates for each path'
  local date first last git_log_dates_cmd
  git_log_dates_cmd=( git log --date=short --format="%cd" )
  while
    case "${1-}" in
      ( --follow ) git_log_dates_cmd+=( "$1" );;
        * ) false
    esac
  do shift
  done
  for path
  do first= last=
    while read -r date
    do
      [[ ${last:+set} ]] && first=$date || last=$date
    done < <("${git_log_dates_cmd[@]}" "$path")
    echo "- $first $last $path"
  done
}

SCM.Git.remotes ()
{
: param '<Dir> <Dest-arr>'
  local -n _sgr_map1=${2:?}
  local name
  while read -r name spec
  do
    : "${spec% \(*)*}"
    : "${_##* }"
    _sgr_map1["$name"]=${_}
  done < <(git --git-dir "$1/.git" remote --verbose)
}

SCM.Git.remotes-byname ()
{
: param '<Dir> <Dest-arr> [<Name-match...>]'
  local -n _sgr_map2=${2:?}
  local name pat match
  while read -r name
  do
    ! (($#-2)) || {
      match=false
      for path in "${@:3}"
      do
        # shellcheck disable=2053 # intentional variable glob
        [[ $name == $pat ]] && match=true && break
      done
      $match || continue
    }
    _sgr_map2["$name"]=$(git --git-dir "$1/.git" config remote.$name.url)
  done < <(git --git-dir "$1/.git" remote)
}

# Id: scm-git                                    vim:set ft=bash sw=2 sts=2 et:
