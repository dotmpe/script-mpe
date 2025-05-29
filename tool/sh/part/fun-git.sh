script_mpe_part_fun_git_load ()
{
  : source script-mpe:tool/sh/part/fun-git.sh
}

git_fun ()
{
  : source script-mpe:tool/sh/part/fun-git.sh
  : require
  wrap_seq__basedirs_with_app_opts git grep \"\$@\"
}


# TODO: provide function part for git-grep.sh functionality
git_grep_all () # ~ <Git-grep-args> [-- <Basedirs>]
{
  local -a git_grep_args
  while [[ $# -gt 0 && $1 != -- ]]
  do
    git_grep_args+=( "$1" )
    shift
  done
  [[ ${#git_grep_args[@]} -gt 0 ]] ||
    _ERROR "Grep expression expected" || return
  shift
  [[ ${#} -gt 0 ]] || {
    local -a _basedirs
    #read -r -a _basedirs <<< "${PATH//:/ }"
    mapfile -t _basedirs <<< "${PATH//:/$'\n'}"
    set -- "${_basedirs[@]}"
  }
  [[ ${#} -gt 0 ]] ||
    _ERROR "Basedirs expected" || return
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

git_status_all () # ~ <Git-status-args> [-- <Basedirs>]
{
  local -a git_status_args
  while [[ $# -gt 0 && $1 != -- ]]
  do
    git_status_args+=( "$1" )
    shift
  done
  shift
  [[ ${#} -gt 0 ]] || {
    local -a _basedirs
    mapfile -t _basedirs <<< "${PATH//:/$'\n'}"
    set -- "${_basedirs[@]}"
  }
  [[ ${#} -gt 0 ]] ||
    _ERROR "Basedirs expected" || return
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

git_grep_versions () # ~ <Expr> <Paths...>
{
  git grep "${1:?}" $(git rev-list ${GIT_REVOPT:=--all}) -- "${@:2}"
}

# ex:ft=bash:
