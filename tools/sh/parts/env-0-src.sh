#!/usr/bin/env bash

: "${SRC_PREFIX:="/src"}"
: "${VND_GH_SRC:="$SRC_PREFIX/github.com"}"
: "${VND_SRC_PREFIX:="$VND_GH_SRC"}"

export SRC_PREFIX VND_SRC_PREFIX VND_GH_SRC
