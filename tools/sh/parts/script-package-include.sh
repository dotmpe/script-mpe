#!/bin/sh

# Look for load file at path and source shell script if found
script_package_include () # SH_EXT=sh ~ SCRIPT_PATH
{
  test $# -eq 1 || return
  set -- "$(realpath "$1")"
  for sh_ext in ${SH_EXT:-"sh"}
  do
    test -f $1/load.$sh_ext || continue
    SCRIPT_SOURCE="$1/load.$sh_ext" . "$1/load.$sh_ext"
    return $?
  done
  unset sh_ext
  return 1
}

# Sync: U-S:tools/sh/parts/script-package-include.sh              vim:ft=bash:
