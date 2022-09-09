#!/bin/sh

project_lib_load()
{
  test -e /srv/project-local/.htd || error "project-local missing" 1
}

htd_project_releases()
{
  . $PACK_SH || true

  local ns_name=$package_vendor app_id=$package_id

  test -n "$ns_name" || ns_name=$NS_NAME
  test -n "$app_id" || app_id=$APP_ID

  github_release_list "$ns_name" "$app_id"
}

# TODO: go from project Id, to namespace and provider.
# Use local SCM/package path or env.
htd_project_args() # [NS/]NAME | [ NAME URL ]]
{
  test -n "$1" || set -- "$package_id"

  # Set defaults
  test -n "$ns" || ns=$NS_NAME
  test -n "$domain" || domain=github.com

  # Get or add Ns to project-id argument
  fnmatch "*/*" "$1" && {
    ns=$(echo "$1" | cut -d'/' -f1)
    name=$(echo "$1" | cut -d'/' -f2-)
  } || {
    name="$1"
    set -- "$ns/$1"
  }

  #test -n "$2" || {
  #  test -n "$1" || error "TODO: get ns/name from package" 1
    #set -- "$1" "$(htd git-remote url dotmpe $1)"
    #vc_getscm || return
    #error "TODO get url" 1
  #  #set -- "$()" "$2"
  #}

  test -n "$1" || {
    error "TODO get Ns-Name for recognized URLs" 1
    #set -- "$(basename "$2" .git)" "$2"
  }
}

# TODO: create new checkout for project
htd_project_checkout()
{
  local ns=
  htd_project_args "$@" || return

}

htd_project_init() # [NS/]NAME | [ NAME URL ]]
{
  local ns= domain= name=
  htd_project_args "$@" || return

  test ! -d "/srv/project-local/$name" || error "Dir exists: '$name'" 1

  test -e "/src/$domain/$ns/$name" || {
    htd_src_init "$domain" "$ns" "$name"
  }
return $?

  # TODO: init local remote
  #test -e "/srv/scm-git-local/git/$1.git" || {
  #  git clone --bare -mirror "$2" "/srv/scm-git-local/git/$1.git" && {
  #    note "Local repo created for $1"
  #  } || error "Clone error" 1
  #} && note "Local repo exists for $1"

  test -e "/srv/project-local/$name" || {
    test ! -h "/srv/project-local/$name" || rm -v "$name"
    ln -vs "/src/$domain/$ns/$name" /srv/project-local/$name
  }
}

# Create new for current
htd_project_create()
{
  test -n "$1" || set -- "$(basename $PWD)"
  htd_project_exists "$1" && {
    warn "Project '$1' already exists"
  } || true

  ( cd "$1"
    htd__git_init_remote &&
    pd add . &&
    pd update . &&
    htd__git_init_version
  ) || return 1
}

# TODO: Check that project is vendored and catalogued
htd_project_exists()
{
  local name=
  test -n "$1" && name="$1" || {
    test -n "$package_id" && name="$package_id"
  }
  test -n "$name" || name="$(basename "$PWD")"

  #pdoc=$HOME/project/.projects.yaml pd__meta_sq get-repo "$name" || return $?
  pdoc=$HOME/project/.projects.yaml pd meta-sq get-repo "$name" || return $?
  #test -e "/srv/project-local/$name" || {
  #  warn "Not a local project: '$name'"
  #  return 1
  #}

  export project_id="$name"
}


htd_project_sync()
{
  false;
}
htd_project_update()
{
  false;
}

# XXX: cleanup

htd__init_project()
{
  local new= confirm=

  cd ~/project

  # Check for existing git, or commit everything to new repo
  test -d "$1/.git" || {
    test -d "$1" && note "Found existing dir" || new=1
    mkdir -vp $1
    ( cd $1; git init ; git add -u; git st )
    test -n "$new" || read -p "Commit everything to git? [yN] " -n 1 confirm
    test -n "$new" -o "$confirm" = "y" || {
      warn "Cancelled commit in $1" 1
    }
    ( cd $1; git commit "Automatic project commit"; htd git-init-remote $1 )
  }

  # Let projectdir handle rest
  test -e "$1" && {
    pd init "$@"
  } || {
    pd add "$@"
  }
}


htd_man_1__init_project2='Initialize project ID

Look for vendorized dir <vendor>.com/$NS_NAME/<project-id> or get a checkout.

Link onto prefix in Project-Dir if not there.
Finish running local htd run init && pd init.
'
#htd_spc__init_project2='init [ [Vendor:][Ns-Name][/]Project ]'
htd_spc__init_project2='init [ Project [Vendor] [Ns-Name] ]'
htd_run_init_project2=pq
htd__init_project2()
{
  test -n "$project_dir" || project_dir=

  #test -n "$1" || set -- . TODO: detect from cwd
  test -n "$2" || {

    test -z "$3" && {
      # Take first found in lists for all vendors?
      true
    } || {
      true
    }
  }
  error TODO 1
  cd ~/project/$pd_prefix
  htd scripts id-exist init && {
    htd run init || return $?
  }
  #pd init
}
