#!/usr/bin/env bash

: "${UCACHE:=""}"
test -n "$UCACHE" || UCACHE=$HOME/.cache/local
test -d "$UCACHE/user-env" || mkdir -p "$UCACHE/user-env"
