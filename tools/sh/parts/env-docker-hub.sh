#!/usr/bin/env bash

ctx_if @DockerHub@Build && {

  test ! -e ~/.local/etc/tokens.d/docker-hub-$DOCKER_NS.sh || {

    . ~/.local/etc/tokens.d/docker-hub-$DOCKER_NS.sh || return
  }

  : "${DOCKER_USERNAME:="$DOCKER_NS"}"
  : "${INIT_LOG:="$PWD/tools/sh/log.sh"}"

  test -n "${DOCKER_PASSWORD:-}" || {
    $INIT_LOG "error" "" "Docker Hub password required" "" 1
  }

}

# Sync: U-S:
