#!/usr/bin/env bash

ctx_if @GitHub@Build && {

  test -n "${GITHUB_TOKEN:-}" || {
    . ~/.local/etc/profile.d/github-user-scripts.sh || exit 101
  }

}

# Sync: U-S:
