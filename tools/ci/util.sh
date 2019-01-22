#!/usr/bin/env bash

# Routines used to help during CI runs

test -z "${ci_util_:-}" && ci_util_=1 || exit 98 # Recursion

test -n "${sh_util_:-}" || {
  . "${sh_tools:="${CWD:="$PWD"}/tools/sh"}/util.sh"
}

sh_include std-ci-helper

# Sync: U-S:
