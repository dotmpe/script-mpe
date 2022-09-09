#!/usr/bin/env bash

@Bookmarks.list()
{
  true
}

ctx__Bookmarks__tabs() # List bookmark table files (on local host)
{
  true
}

ctx__Bookmarks__dbs() # List bookmark DB files (on local host)
{
  true
}

ctx__Bookmarks__status() # Show status for file and DB
{
  echo TODO: ctx:Bookmarks status $*
}

ctx__Bookmarks__check() # Update status bits
{
  echo TODO: ctx:Bookmarks status $*
  # Check wether times in DB match file records
  # Check wether import locations are new, or within due-dates
}

ctx__Bookmarks__import() # ~ Tags... # Run importers
{
  test -n "${1-}" || return
  context_load "$@" || return
  local contex_meta_importers="$(echo " $rest "|sed 's/^.*\ import:\([^\ ]*\)\ .*$/\1/'|tr ',' ' ')"

  #lib_load str-htd urlstat

  # XXX: for DB generate urlstat.tab for diff

  # XXX: for chrome generate urlstat.tab for diff

  # XXX: for diigo look for export

  # XXX: for google fetch https://www.google.com/bookmarks/?output=xml&num=10000
  for importer in $contex_meta_importers
  do
    urlstat_${importer}_import
  done
}

#
