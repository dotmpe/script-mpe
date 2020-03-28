#!/bin/sh

script_package_include() # SH_EXT ~ SCRIPT_PATH
{
  set -- "$(realpath "$1")"
  for sh_ext in $SH_EXT sh
  do
    test -f $1/load.$sh_ext || continue
    SCRIPT_SOURCE="$1/load.$sh_ext" . "$1/load.$sh_ext"
    return $?
  done
  unset sh_ext
  return 1
}

# Id: BIN:tools/sh/parts/script-package-include.sh                vim:ft=bash:
