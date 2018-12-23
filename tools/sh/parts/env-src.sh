#!/bin/ash

: "${SRC_PREFIX:=/src}"
: "${VND_SRC_PREFIX:=$SRC_PREFIX}"
: "${VND_GH_SRC:=$VND_SRC_PREFIX/github.com}"
export SRC_PREFIX VND_SRC_PREFIX VND_GH_SRC
