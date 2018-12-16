#!/bin/sh

git_lib_load()
{
  test -n "$SRC_DIR" || SRC_DIR=/src
  test -n "$SCM_VND" || SCM_VND=github.com
  test -n "$VND_GH_SRC" || VND_GH_SRC=$SRC_DIR/$SCM_VND
  test -n "$GIT_SCM_SRV" || GIT_SCM_SRV=/srv/scm-git-local
  test -n "$GIT_SCM_SRVS" || GIT_SCM_SRVS=/srv/scm-git-*/
  test -n "$LOCAL_SRC" || LOCAL_SRC=$SRC_DIR/local
  test -n "$PROJECT_DIR" || {
    test -e "/srv/project-local" &&
      PROJECT_DIR=/srv/project-local || PROJECT_DIR=$HOME/project
  }
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

git_lib_init()
{
  test -d "$SRC_DIR" &&
  test -d "$VND_GH_SRC" &&
  test -d "$GIT_SCM_SRV" &&
  test -d "$PROJECT_DIR"
}

# Use find to list repos on $PROJECTS path
git_list() # PROJECTS ~
{
  for path in $(echo "$PROJECTS" | tr ':' '\n' | realpaths | remove_dupes )
  do
    find $path -iname '.git' -type d -exec dirname "{}" \;
  done
}

# Compile table of remote-name, remote-URL, repository-name, group and vendor
git_src_info()
{
  git_list | vc_dirtab
}

git_scm_list() # [PROJECTS_SCM] ~ [*.git]
{
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

# Find repo with and path or return err status
git_scm_find() # <user>/<repo>
{
  git_scm_find_out="$(setup_tmpf -scm-find.out)"
  { test -e "$GIT_SCM_SRV/$1.git" && {
      echo "$GIT_SCM_SRV/$1.git"
    } || {
      git_scm_list "*$1.git"
    }
  } | tee "$git_scm_find_out"
  test $(count_lines "$git_scm_find_out") -gt 0
}

git_scm_get() # VENDOR <user>/<repo>
{
  git clone --bare https://$1/$2.git $GIT_SCM_SRV/$2.git
}

# Checkout at $VND_GH_SRC tree, and make link to $PROJECT_DIR
git_src_get() # <user>/<repo>
{
  test -n "$1" || return

  test -e "$VND_GH_SRC/$1" -a ! -e "$VND_GH_SRC/$1/.git" && {

    sys_confirm "Found non-GIT checkout dir, remove?" || return
    rm -rf "$VND_GH_SRC/$1"
  }

  test -e "$VND_GH_SRC/$1" || {
    note "Creating main user checkout for $1..."
    lib_load volume
    remote_name=$( get_cwd_volume_id "$SRC_DIR" )
    test -n "$remote_name" || remote_name=local

    git clone "$GIT_SCM_SRV/$1.git" "$VND_GH_SRC/$1" \
      --origin "$remote_name" --branch "$vc_br_def" || return
    # Add local bare-repo, and update from remote as well
    ( cd  "$VND_GH_SRC/$1" &&
      git remote add "$vc_rt_def" "http://$SCM_VND/$1.git" || return
      # Update local head and tag refs and
      git fetch "$vc_rt_def" &&
      git fetch --tags "$vc_rt_def" &&
      git push "$remote_name"
    )
  }

  name="$(basename "$1")"
  test -e "$PROJECT_DIR/$name" && {
    echo "$1: $PROJECT_DIR/$name -> $(readlink "$PROJECT_DIR/$name")"
  } || {
    test -h "$PROJECT_DIR/$name" && rm -v "$PROJECT_DIR/$name"
    ln -vs "$VND_GH_SRC/$1" "$PROJECT_DIR/$name"
  }
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
