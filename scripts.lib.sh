#!/bin/sh

set -e


scripts_lib_load()
{
  trueish "$package_lib_loaded"
}


htd_scripts_names()
{
  test -e "$PACKMETA_JS_MAIN" || error "No '$PACKMETA_JS_MAIN' file" 1
  jsotk.py keys -O lines $PACKMETA_JS_MAIN scripts
}

htd_scripts_list()
{
  htd_scripts_names | while read name
  do
    printf -- "$name\n"
    verbose_no_exec=1 htd__run $name
  done
}
