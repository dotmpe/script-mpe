#!/usr/bin/env bash

case " $CTX $CTX_P " in *" @Docker "* )

test ! -e ~/.local/etc/tokens.d/docker-hub-$DOCKER_NS.sh || {

  . ~/.local/etc/tokens.d/docker-hub-$DOCKER_NS.sh || return
}

: "${DOCKER_USERNAME:="$DOCKER_NS"}"
: "${INIT_LOG:="$PWD/tools/sh/log.sh"}"

test -n "${DOCKER_HUB_PASSWD:-}" || {
  $INIT_LOG "error" "" "Docker Hub password required" "" 1
}

;; esac

# Sync: U-S:
