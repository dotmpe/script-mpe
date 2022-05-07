#!/bin/sh

htd_man_1__catalog='Build file manifests. See `htd help htd-catalog-*` for more
details per function. The main commands to use are:

  index PATH
    For paths below PATH, check entries exists and XXX: add entries
  organize PATH
    For elements below PATH, XXX: add as special group or new entries

Sets of catalogs

  [CATALOGS=.catalogs] list-local
    find catalog documents, cache full paths at CATALOG and list pathnames
  [CATALOG_DEFAULT=] name [DIR]
    select and set CATALOG filename from existing catalog.y*ml
  find STR
    for every catalog from "htd catalog list-local", look for literal string in it
  ignores
    List ignore patterns to apply to local file listings (global, ignore and scm
    groups)
  update-ignores
    Update CATALOG_IGNORES file from ignores
  listdir DIR
    List local files for cataloging, excluding dirs but including symlinked
  listtree PATH
    List untracked files for SCM dir, else find everything with ignores.

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
htd__catalog ()
{
  test -n "${1-}" || set -- status
  subcmd_prefs=${base}_catalog__ try_subcmd_prefixes "$@"
}
htd_flags__catalog=ilIAO
htd_libs__catalog='match str-htd date-htd schema list ignores file archive ck-htd ck catalog' # XXX: match-htd statusdir src-htd

htd_als__catalogs='catalog list'
htd_als__fsck_catalog='catalog fsck'

htd_catalog__help ()
{
  #std_help catalog
  echo "$htd_man_1__catalog"
}

htd_catalog__info () # Some catalog info ~
{
  $LOG header $scriptname:catalog:info

  $LOG header2 "Catalog-Default" "$CATALOG_DEFAULT"
  $LOG header2 "Catalog" "$CATALOG" "$(echo $( filesize "$CATALOG" && {
      count_lines "$CATALOG"; echo bytes/lines
    } || echo missing ))"
  $LOG header2 "Catalogs" "$CATALOGS" "$(echo $( filesize "$CATALOGS" && {
      count_lines "$CATALOGS"; echo bytes/lines
    } || echo missing ))"
  $LOG header2 "Global-Catalogs" "$GLOBAL_CATALOGS" "$(echo $(
    filesize "$GLOBAL_CATALOGS" && {
        count_lines "$GLOBAL_CATALOGS"; echo bytes/lines
    } || echo missing ))"
  $LOG header2 "global" "$choice_global"
}

htd_catalog__listtree ()
{
  catalog_listtree "$@"
}

htd_catalog__refresh_ignores ()
{
  ignores_refresh
}

htd_catalog__update_ignores ()
{
  ignores_cache
}


htd_catalog_lib_load ()
{
  # Global catalog list file
  test -n "${GLOBAL_CATALOGS-}" || GLOBAL_CATALOGS=$HTD_CONF/catalogs.list
  test -n "${choice_global:-}" || choice_global=0

  test -n "${dry_run:-}" || {
      test -z "${noact:-}" && dry_run=0 || dry_run=$noact
    }
  test -n "${keep_going:-}" || keep_going=1

}

# Id: BIN:
