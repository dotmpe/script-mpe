#!/bin/sh

set -e


scripts_lib_load()
{
  trueish "$package_lib_loaded"
}


htd_scripts_names()
{
  test -e "$PACKMETA_JS_MAIN" || error "No '$PACKMETA_JS_MAIN' file" 1
  jsotk.py keys -O lines $PACKMETA_JS_MAIN scripts | sort -u | {
      test -n "$1" && {
          while read name ; do
              fnmatch "$1" "$name" || continue ; echo "$name"; done
      } || { cat - ; }
  }
}

htd_scripts_list()
{
  test -n "$package_id" || error "No package env loaded" 1
  htd_scripts_names "$@" | while read name
  do
    printf -- "$name\n"
    verbose_no_exec=1 htd__run $name
  done
}

htd_scripts_id_exist()
{
  test "$1" = "$(htd scripts names "$1")"
}
