#!/bin/sh


# XXX: get at some compiled info for /src
htd_git_info()
{
  test -n "$info_doc" || info_doc=$STATUSDIR_ROOT/index/git-src.list
  #test "$info_doc" -nt
  git_src_info >"$info_doc"

  note "OK, $(cut -f1 -d' ' "$info_doc" | sort -u | count_lines) unique local remote names"
  note "OK, $(cut -f2 -d' ' "$info_doc" | sort -u | count_lines) unique URL refs"
  note "OK, $(cut -f3 -d' ' "$info_doc" | sort -u | count_lines) repositories"
  note "OK, $(cut -f4 -d' ' "$info_doc" | sort -u | count_lines) users and teams"
  note "OK, $(cut -f5 -d' ' "$info_doc" | sort -u | count_lines) vendors or basedirs"
}

htd_git_find() # <user>/<repo>
{
  local git_scm_find_out= r=
  git_scm_find "$1" || r=$?
  rm "$git_scm_find_out"
  return $r
}

# Setup if new, or check symlink and version.
htd_git_get() # <user>/<repo> [Version]
{
  fnmatch "*/*" "$1" || {
    test -n "$NS_NAME" || error "Ns-Name required" 1
    set -- "$NS_NAME/$1" "$2"
  }
  local git_scm_find_out=
  git_scm_find "$1" || {

    git_scm_get "$SCM_VND" "$1" || return
  }

  lib_load volume
  git_src_get "$1" || return
  rm "$git_scm_find_out"
}

htd_git_req()
{
  git_require "$@"
}

# Make a reference checkout at $LOCAL_SRC and set it to commit
#
# The environment has to evaluate so that environment-version
# indicates the required commit, and environment-name (or env-name)
# to the wanted dir beneath $LOCAL_SRC.
#
# If set, the environment-cwd can either be used in the symlink,
# or with Git 2.19 --filter to checkout a subdirectory.
#
# ``package.y*ml``
#
#   environment_version
#   environment_cwd
#   environment_env
#
#   package_version
#   package_env_name
#   package_env
#
htd_git_get_env() # [ENV] <user>/<repo> [BRANCH]
{
  fnmatch "*/*" "$2" || {
    test -n "$NS_NAME" || error "Ns-Name required" 1
    set -- "$1" "$NS_NAME/$2" "$3"
  }
  git_scm_find "$2" >/dev/null || {

    git_scm_get "$SCM_VND" "$1" || return
  }
  test -n "$1" || set -- "ENV_VER=$3" "$2" "$3"
  environment_env "$1" || return
  git_get_branch "$env" "$SCM_VND" "$2"
}
