#!/bin/sh

ignores_load()
{
  test -n "$1" || set -- $base
  test -n "$2" || set -- $1 $(str_upper $1)

  local varname=${2}_IGNORE fname=.${1}ignore
  test -n "$IGNORE_GLOBFILE" \
    && fname=$IGNORE_GLOBFILE \
    || IGNORE_GLOBFILE=$fname

  test -n "$(eval echo "\$$varname")" || eval $varname=$fname
  local value="$(eval echo "\$$varname")"
  test -e "$value" || {
    value=$(setup_tmpf $fname)
    eval $varname=$value
    IGNORE_GLOBFILE=$value
    touch $value
  }
  export $varname IGNORE_GLOBFILE
}

glob_to_find_prune()
{
  # Filter matches on name
  echo $(echo "$1" | \
    grep -Ev '^(#.*|\s*)$' | \
    sed -E 's/^\//\.\//' | \
    grep -v '\/' | \
    sed -E 's/(.*)/ -o -name "\1" -prune /g')
  # Filter matches on other paths
  echo $(echo "$1" | \
    grep -Ev '^(#.*|\s*)$' | \
    sed -E 's/^\//\.\//' | \
    grep '\/' | \
    sed -E 's/(.*)/ -o -path "*\1*" -prune /g')
}

find_ignores()
{
  for a in $@
  do
    # Translate gitignore lines to find flags
    read_nix_style_file $a | while read glob
      do glob_to_find_prune "$glob"; done
  done
}


