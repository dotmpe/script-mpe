#!/bin/sh


htd_cabinet_lib__load()
{
  default_env Cabinet-Dir "cabinet" || debug "Using Cabinet-Dir '$CABINET_DIR'"
  default_env Jrnl-Dir "personal/journal" || debug "Using Jrnl-Dir '$JRNL_DIR'"
}


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

htd_spc__cabinet='cabinet [CMD ARGS..]'
htd__cabinet()
{
  cabinet_req
  eval set -- $(lines_to_args "$arguments") # Remove options from args
  subcmd_prefs=${base}_cabinet_\ cabinet_ try_subcmd_prefixes "$@"
}
htd_flags__cabinet=ilAO
htd_argsv__cabinet()
{
  opt_args "$@"
}
htd_libs__cabinet="str-htd"


htd_man_1__archive_path='
# TODO consolidate with today, split into days/week/ or something
'
htd_spec__archive_path='archive-path DIR PATHS..'
htd__archive_path()
{
  test -n "$1" || set -- cabinet/
  test -d "$1" || {
    fnmatch "*/" "$1" && {
      error "Dir $1 must exist" 1
    } || {
      test -d "$(dirname "$1")" ||
        error "Dir for base $1 must exist" 1
    }
  }
  fnmatch "*/" "$1" || set -- "$1/"

  Y=/%Y M=-%m D=-%d archive_path "$1"

  datelink -1d "$archive_path" ${ARCHIVE_DIR}yesterday$EXT
  echo yesterday $datep
  datelink "" "$archive_path" ${ARCHIVE_DIR}today$EXT
  echo today $datep
  datelink +1d "$archive_path" ${ARCHIVE_DIR}tomorrow$EXT
  echo tomorrow $datep

  unset archive_path archive_path_fmt datep target_path
}
# declare locals for unset
htd_vars__archive_path="Y M D EXT ARCHIVE_BASE ARCHIVE_ITEM datep target_path"


htd_cabinet_add() # Refs
{
  test -n "${1-}" || warn "expected references to backup" 1
  { test -n "$1" && { foreach "$@" || return ; } || cat ; } | sed 's/\/$//' |
  # Add trailing '/' for first and remove for second, for rsync to handle dir
    while read p ; do test -d "$p" && echo "$p/" || echo "$p" ; done |
    archive_path_map | sed 's/\/$//' | rsync_pairs
}

#
