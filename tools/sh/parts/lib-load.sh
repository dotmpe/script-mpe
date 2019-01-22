#!/usr/bin/env bash

test -z "${DEBUG:-}" || {
  set -x || true;
}

. "$CWD/tools/sh/init.sh" || return

test -z "${DEBUG:-}" || {
  set +x || true;
}

# Sync: U-S:
