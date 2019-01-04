#!/usr/bin/env bash

test -n "${GITHUB_TOKEN:-}" || {
  . ~/.local/etc/profile.d/github-user-scripts.sh || exit 101
}
