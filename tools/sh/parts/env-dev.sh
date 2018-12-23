#!/bin/ash

# Locate ztombol helpers and other stuff from github
test -n "$VND_SRC_PREFIX" || VND_SRC_PREFIX=/srv/src-local
test -n "$VND_GH_SRC" || VND_GH_SRC=$VND_SRC_PREFIX/github.com
