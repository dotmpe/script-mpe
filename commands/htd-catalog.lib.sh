#!/bin/sh
htd_man_1__catalog='Build file manifests. See `htd help htd-catalog-*` for more
details per function.

Sets of catalogs

  [CATALOGS=.catalogs] list-local
    find catalog documents, cache full paths at CATALOG and list pathnames
  [CATALOG_DEFAULT=] name [DIR]
    select and set CATALOG filename from existing catalog.y*ml
  find STR
    for every catalog from "htd catalog list-local", look for literal string in it
  list-files
    List local catalog names
  ignores
    List ignore patterns to apply to local file listings (global, ignore and scm
    groups)
  update-ignores
    Update CATALOG_IGNORES file from ignores
  listdir DIR
    List local files for cataloging, excluding dirs but including symlinked
  listtree PATH
    List untracked files for SCM dir, else find everything with ignores.
  index PATH
    List tree, check entries exists
  organize PATH

Single catalogs

  [CATALOG=] check
    Update cached status bits (see validate and fsck)
  [CATALOG=] status
    Run "check" and set return code according to status
  [CATALOG=] add [DIR|FILE]
    Add file, recording name, basic keys, and other file metadata.
    See also add-file, add-from-folder, add-all-larger,
  annex-import [Annex-Dir] [Annexed-Paths...]
    Update entries from Annex (backend key and/or metadata)

  ck [CATALOG}
    print file checksums
  fsck [CATALOG]
    verify file checksums
  validate [CATALOG]
    verify catalog document schema
  doctree
    TODO doctree
  listtree
    List untracked files (not in SCM), or find with local ignores
  untracked
    List untracked files (not in SCM or ignored) not in catalog

Single catalog entry

  [CATALOG=] get-path NAME
    Get src-file (full path) for record
  [CATALOG=] drop NAME
    Remove record
  [CATALOG=] delete NAME
    Remove record and src-file
  drop-by-name [CATALOG] NAME
    See drop.
  copy NAME [DIR|CATALOG]
    Copy record and file to another catalog and relative src-path
  move NAME [DIR|CATALOG]
    Copy and drop record + delete file
  set [CATALOG] NAME KEY VALUE
    Add/set any string value for record.
  update [CATALOG] Entry-Id Value [Entry-Key]
    Update single key of signle entry in catalog JSON and write back.

Functions without CATALOG argument will use the likenamed env. See
catalog-lib-load. Std. format is YAML.
'

htd_catalog__help ()
{
  echo "$htd_man_1__catalog"
}
