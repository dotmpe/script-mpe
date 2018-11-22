#!/bin/sh


htd_cabinet_add() # Refs
{
  test -n "$1" || warn "expected references to backup" 1
  { test -n "$1" && { foreach "$@" || return ; } || cat ; } | sed 's/\/$//' |
  # Add trailing '/' for first and remove for second, for rsync to handle dir
    while read p ; do test -d "$p" && echo "$p/" || echo "$p" ; done |
    archive_path_map | sed 's/\/$//' | rsync_pairs
}
