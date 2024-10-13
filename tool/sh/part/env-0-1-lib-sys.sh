#!/usr/bin/env bash

: ${HOST:="`hostname -s`"}
: ${uname:="`uname -s`"}

# XXX: remove this and use directly, see also U-S:tool/sh/part/env-gnu.sh
. ~/.conf/etc/profile.d/gnu.sh

# Sync: U-S:
