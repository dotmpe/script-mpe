#!/usr/bin/env bash
test -z "${sh_util_:-}" && sh_util_=1 || return 198 # Recursion


# TODO: move some of below to CI util.sh

. $HOME/bin/tools/sh/init-include.sh # Initialize sh_include

sh_include \
  str-bool str-id read exec \
  unique-paths hd-offsets suite-from-table suite-source suite-run


# Sync: X-CI-0.1:
# Sync: U-S:
