#!/bin/sh

git_htd_lib_load()
{
  test -n "$GIT_SCM_SRVS" || GIT_SCM_SRVS=/srv/scm-git-*/
  test -n "$LOCAL_SRC" || LOCAL_SRC=$SRC_DIR/local
  lib_load git
  test -n "$PROJECTS_SCM" || {
    PROJECTS_SCM="$(for path in /srv/scm-git-local $GIT_SCM_SRVS
      do
          echo ":$path"
      done | remove_dupes | tr -d '\n' | tail -c +2 )"
  }
  test -n "$PROJECTS" || {
    PROJECTS="$(for path in $PROJECT_DIR $HOME/project /srv/project-local /src/*.*/ /src/local/
      do
          echo ":$path"
      done | remove_dupes | tr -d '\n' | tail -c +2 )"
  }
  lib_load environment statusdir vc-htd gitremote &&
    statusdir_init
}

# Compile table of remote-name, remote-URL, repository-name, group and vendor
git_src_info()
{
  { git_list || return
  } | vc_dirtab
}

git_scm_list() # [PROJECTS_SCM] ~ [*.git]
{
  test $# -le 2 || return
  while test $# -lt 2 ; do set -- "$@" "" ; done
  test -n "$1" || set -- "*.git"
  fnmatch "*/*" "$1" && set -- "$1" "$1"
  for path in $(echo "$PROJECTS_SCM" | tr ':' '\n' | realpaths | remove_dupes )
  do
    test -n "$2" && {
      find $path -ipath "$2" -type d
    } || {
      find $path -iname "$1" -type d
    }
  done
}

git_require() # <user>/<repo> [Check-Branch]
{
  test -n "$1" -a -n "$2" || return
  test -n "$2" || set -- "$1" "$vc_br_def"

  vc_br_def=$2 git_src_get "$SCM_VND" "$1"

  for local_env in $LOCAL_SRC/*/$SCM_VND/$1
  do
    test "$2" = "$(vc_branch "$local_env")" && {
      echo $local_env
      return 0
    }
  done

  test "$2" = "$(vc_branch "$VND_GH_SRC/$1")" || {
    warn "Project checkout $1 is not at version '$2'" 1
  }
  echo "$VND_GH_SRC/$1"
}

# XXX: fix naming. Get a path to required branch environment_version
git_get_branch() # [ENV] <user>/<repo>
{
  eval "$1" || return
  test -n "$environment_name" -a -n "$environment_version"  || return
  mkdir -vp "$(dirname "$LOCAL_SRC/$environment_name/$SCM_VND/$2")" || return
  git clone --reference "$GIT_SCM_SRV/$2.git" \
      --branch "$environment_version" \
      --origin "local-ref" \
       "https://$SCM_VND/$2.git" \
      "$LOCAL_SRC/$environment_name/$SCM_VND/$2"
}

git_describe_parse()
{
  test $# -le 1 || return 98
  local tag="${1-:}"
  test -n "$tag" || tag=$(git describe --always)

  fnmatch "*-g[0-9a-f][0-9a-f][0-9a-f]*" "$tag" && {

    last_tag=$(printf %s "$tag"|sed 's/^\(.*\)-[0-9][0-9]*-g[0-9a-f]*$/\1/')
    commits_since=$(printf %s "$tag"|sed 's/^.*-\([0-9][0-9]*\)-g[0-9a-f]*$/\1/')
    abbrev_sha1=$(printf %s "$tag"|sed 's/^.*-[0-9][0-9]*-g\([0-9a-f][0-9a-f]*\)$/\1/')
    return
  } || {
    last_tag=
    commits_since=
    abbrev_sha1=
    sha1=$tag
    return 1
  }
}
