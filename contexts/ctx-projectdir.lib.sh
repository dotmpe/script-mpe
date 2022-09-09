#!/bin/sh

at_Projectdir__at_Rules__cwd ()
{
  read_nix_style_file ${STATUSDIR_ROOT}index/pd-$hostname.list |
    tr -s ' ' ' ' |
    grep -v '^ *$' |
    cut -d' ' -f3 | { local pdir; while read pdir
  do
    test -e "$pdir" || continue
    echo "$pdir"
  done; }
}

#
