#!/bin/sh

docker_sh_htd_lib_load()
{
  test -n "$docker_shell" || docker_shell=bash
  test -n "$docker_cmd" || docker_cmd=bash
  lib_load docker-sh

  test -n "${repo_slug:-}" || {
    test -n "$APP_ID" || return 100
    : "${repo_slug:="$NS_NAME/$APP_ID"}"
  }
}

docker_sh_c_update() # Container [Image]
{
  test -n "$1" || set -- "$docker_sh_c" "$2"
  test -n "$1" || set -- "$docker_name" "$2"
  test -n "$2" || set -- "$1" "$docker_image"
  test -n "$2" || {
    docker_sh_c exists "$1" || return
    test -n "$2" || set -- "$1" "$( docker_sh_c_image_name "$1" )"
  }

  ${dckr_pref}docker pull "$2"
  docker_sh_c is_running "$1" || return 0
  docker_sh_c_recreate "$@" || return
}

docker_sh_c_require()
{
  docker_sh_c is_running "$@" || {

    docker_sh_c_exists "$@" && {
      docker_sh_c_start "$@" || return
      docker_sh_c is_running "$@" || return
    } || {

      docker_sh_c_create "$@" || return
    }

    docker_sh_c is_running "$@"
  }
}

docker_sh_c_require_updated()
{
  docker_sh_c_exists "$1" && {

    docker_sh_c is_running "$@" || {
      docker_sh_c_start "$@" || return
    }
    docker_sh_c_update "$@" || return

  } || {

    echo not runing, updating
    docker_sh_c_update "$@" || return
    docker_sh_c_create "$@" || return
  }

  docker_sh_c is_running "$1"
}

docker_sh_c_run() # [Container]
{
  docker_sh_c_exists "$1" && {
    docker_sh_c_start "$@"
  } || {
    docker_sh_c_create "$@"
  }
}

docker_sh_c_create() # [Container] [Docker-Image]
{
  test -n "$1" || set -- "$docker_name" "$2" "$3"
  test -n "$2" || set -- "$1" "$docker_image" "$3"
  test -n "$3" || set -- "$1" "$2" "$docker_cmd"

  # FIXME: normal treebox superuser setup on Darwin has owner id probs?
  #echo "%supergroup  ALL=NOPASSWD:ALL" >.etc-sudoers.d-treebox-supergroup
  #  -v $PPWD/.etc-sudoers.d-treebox:/etc/sudoers.d/treebox-supergroup \

  local user=treebox home=/home/treebox dut=

  # FIXME: Hardcoded Notus volumes
  #    -v ~/bin:/home/treebox/bin \
  dut=$home/test/$repo_slug
  ${dckr_pref} docker run \
      -v $PPWD:$dut \
      -v ~/.ssh:$home/.ssh:ro \
      -v $(realpath ~/.local/etc/tokens.d):$home/.local/etc/tokens.d \
      -v $(realpath /etc/localtime):/etc/localtime \
      -v $(realpath /srv/scm-git-24-2-notus-brix/):/srv/scm-git-24-2-notus-brix \
      -v /var/run/docker.sock:/var/run/docker.sock \
      -di --name "$1" "$2" "$3" || return

  # TODO: one-time-init, maybe use init/service scripts inside container here
  func_exists docker_sh_c_init && docker_init=docker_sh_c_init
  test -z "$docker_init" || {
    note "Docker init: $docker_init"
    $docker_init "$1"
  }
}

docker_sh_c_recreate() # [Container] [Docker-Image]
{
  docker_sh_c_delete "$1" && docker_sh_c_create "$1" "$2"
}

docker_sh_c_start() # [Container]
{
  ${dckr_pref}docker start -i "$1"
}

docker_sh_c_delete() # [Container]
{
  ${dckr_pref}docker rm -f "$1"
}

docker_sh_c_id() # [Container]
{
  docker_sh_c_inspect '{{.Id}}' "$@"
}

docker_sh_c_is_running() # [Container]
{
  trueish "$( docker_sh_c_inspect '{{.State.Running}}' "$@" )"
}