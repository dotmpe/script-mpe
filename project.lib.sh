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

# TODO: go from project Id, to namespace and provider. use local SCM/package
htd_project_args()
{
  test -n "$2" || {
    test -n "$1" || error "TODO: get ns/name from package" 1
    set -- "$1" "$(htd git-remote url dotmpe $1)"
    #vc_getscm || return
    #error "TODO get url" 1
  #  #set -- "$()" "$2"
  }

  test -n "$1" || {
    error "TODO get Ns-Name for recognized URLs" 1
    set -- "$(basename "$2" .git)" "$2"
  }
  fnmatch "*/*" "$1" && ns=$(echo "$1" | cut -d'/' -f1) || set -- "$ns/$1"
}
# TODO: create new checkout for project
htd_project_checkout()
{
  local ns=$NS_NAME
  htd_project_args "$@" || return
  test -n "$domain" || domain=github.com

  test -e "/src/$domain/$ns/$name" || {
    git clone "$2" "/src/$domain/$ns/$name"
  }
  test -e "/srv/project-local/$name" || {
    ln -s "/src/$domain/$ns/$name" /srv/project-local/$name
  }
}
# TODO: check that project is vendored
htd_project_init() # [NS/]NAME | [ NAME URL ]]
{
  local ns=$NS_NAME
  htd_project_args "$@" || return

  test -e "/srv/git-local/git/$1.git" || {
    git clone --bare -mirror "$2" "/srv/git-local/git/$1.git" && {
      note "Local repo created for $1"
    } || error "Clone error" 1
  } && note "Local repo exists for $1"
}
# Create new for current
htd_project_create()
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
# check that project is vendored
htd_project_exists()
{
  false
}
htd_project_sync()
{
  false;
}
htd_project_update()
{
  false;
}
