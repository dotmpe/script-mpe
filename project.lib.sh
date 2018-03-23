#!/bin/sh

project_lib_load()
{
  test -e /srv/project-local || error "project-local missing" 1
}

htd_project_releases()
{
  . $PACKMETA_SH || true
  local ns_name=$package_vendor app_id=$package_id gh_r_j=
  test -n "$ns_name" || ns_name=$NS_NAME
  test -n "$app_id" || app_id=$APP_ID

  gh_r_j=$HOME/.statusdir/web/github.com/$ns_name/$app_id/releases.json
  mkdir -p $(dirname $gh_r_j)

  test -e "$gh_r_j" ||
      github-release info --user $ns_name --repo $app_id -j > $gh_r_j

  test "null" = "$(jq -r '.Releases' $gh_r_j)" && {
      test "null" = "$(jq -r '.Tags' $gh_r_j)" && warn "No tags or releases" ||
          jq -r '.Tags | to_entries[] as $k | $k.value.name,$k.value.tarball_url' $gh_r_j
  } ||
      jq -r '.Releases | to_entries[] as $k | $k.value.tag_name,$k.value.tarball_url' $gh_r_j
}

# Create new for current
htd_project_new()
{
  test -n "$1" || set -- "$(basename $(pwd))"
  htd__project exists "$1" && {
    warn "Project '$1' already exists"
  } || true

  ( cd "$1"
    htd__git_init_remote &&
    pd add . &&
    pd update . &&
    htd__git_init_version
  ) || return 1
}
htd_project_init()
{
  # TODO: go from project Id, to namespace and provider
  #git@github.com:bvberkum/x-docker-hub-build-monitor.git
  false;
}
htd_project_create()
{
  test -n "$1" || error "url expected" 1
  test -n "$2" || error "name expected" 1
}
htd_project_sync()
{
  false;
}
htd_project_update()
{
  false;
}
