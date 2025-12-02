scm_git_pre=SCM.Git
scm_git_grp=( 'user-dirs' )
scm_git_fun=(
  .at-basedirs
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
  [.grep-all-versions]='GIT_REVOPT=--all SCM.Git.grep-revopt'
  [git-grep-dirs]='.grep-at'
  [git-status-all]='.status-at'
)
declare -gA \
scm_git_hooks=(
  [define]=\
'User.Config.expand-keymatch-filterhandle  user_annex  basedir.annexes-local  test -d'
  [init]=\
'user_config[basedir.annexes-local]="/srv/annex-local/*/"'
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
