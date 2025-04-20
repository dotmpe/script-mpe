script_mpe_part_fun_git_load ()
{
  : source script-mpe:tool/sh/part/fun-git.sh
}

git_fun ()
{
  : source script-mpe:tool/sh/part/fun-git.sh
}

# TODO: provide function part for git-grep.sh functionality
git_grep_all () # ~ <Git-grep-args> [-- <Basedirs>]
{
  local tp
  local -a git_grep_args
  while [[ $# -gt 0 && $1 != -- ]]
  do
    git_grep_args+=( "$1" )
    shift
  done
  [[ ${#git_grep_args[@]} -gt 0 ]] ||
    _ERROR "Grep expression expected" || return
  test $# -gt 0 || {
    local -a _basedirs
    read -r -a _basedirs <<< "${PATH//:/$'\n'}"
    set -- -- "${_basedirs[@]}"
  }
  shift
  for tp
  do
    std_quiet pushd "$tp" || return
    "${QUIET:-false}" ||
      stderr echo "$tp> $ git grep '${git_grep_args[*]}'"
    git "${git_args[@]}" grep "${git_grep_args[@]}"
    std_quiet popd
  done
}

git_grep_versions () # ~ <Expr> <Paths...>
{
  git grep "${1:?}" $(git rev-list ${GIT_REVOPT:=--all}) -- "${@:2}"
}
