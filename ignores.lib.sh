#!/bin/sh

ignores_load()
{
  test -n "$1" || set -- $base
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
  for a in "$@"
  do
    # Translate gitignore lines to find flags
    mv $a.merged $a.tmp
    sort -u $a.tmp > $a.merged
    read_nix_style_file $a.merged | while read glob
    do glob_to_find_prune "$glob"; done
    rm $a.tmp
  done
}

