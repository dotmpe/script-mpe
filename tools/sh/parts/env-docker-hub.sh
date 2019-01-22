#!/usr/bin/env bash

test ! -e ~/.local/etc/tokens.d/docker-hub-$DOCKER_NS.sh || {

  . ~/.local/etc/tokens.d/docker-hub-$DOCKER_NS.sh || return
}

: "${DOCKER_USERNAME:="$DOCKER_NS"}"
: "${INIT_LOG:="$PWD/tools/sh/log.sh"}"

test -n "${DOCKER_HUB_PASSWD:-}" || {
  $INIT_LOG "error" "" "Docker Hub password required" "" 1
}

# Sync: U-S:
