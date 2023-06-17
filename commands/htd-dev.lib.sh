#!/bin/sh

# Commands / Htd Dev lib: temporary place for @Dev scripts tied into htd.sh

htd__dev ()
{
  test $# -gt 0 || set -- list
  test $# -gt 1 && {
    t=${2:?"Expected topic tag"}
    #htd__dev tag-exists && {
    #  htd__dev note-exists &&
    #}
  }
  case "${1:-}" in
    ( note ) # ~ <Topic>
        lib_require ctx-htd && lib_init $lib_loaded || return
        create idx StatTab ${HTDIR:?}/.meta/stat/index/context-dev.list &&
        devtag=$($idx.fetch "$t") &&
        $devtag.edit-notes ;;
    ( list )
      ;;
  esac
}

#
