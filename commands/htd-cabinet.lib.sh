#!/bin/sh

htd_man_1__cabinet='Manage files, folders with perma-URL style archive-paths

  cabinet add [--{not-,}-dry-run] [--archive-date=] REFS..
    Move path to Cabinet-Dir, preserving timestamps and attributes. Use filemtime
    for file unless now=1.

        <refs>...  =>  <Cabinet-Dir>/%Y/%m/%d-<ref>...

Env
    CABINET_DIR $PWD/cabinet $HTDIR/cabinet
'

htd_cabinet__help ()
{
  echo "$htd_man_1__cabinet"
}

htd_cabinet_add() # Refs
{
  test -n "${1-}" || warn "expected references to backup" 1
  { test -n "$1" && { foreach "$@" || return ; } || cat ; } | sed 's/\/$//' |
  # Add trailing '/' for first and remove for second, for rsync to handle dir
    while read p ; do test -d "$p" && echo "$p/" || echo "$p" ; done |
    archive_path_map | sed 's/\/$//' | rsync_pairs
}
