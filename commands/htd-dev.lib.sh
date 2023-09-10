#!/bin/sh

# Commands / Htd Dev lib: temporary place for @Dev scripts tied into htd.sh

htd__dev ()
{
  htd_wf_ctx_sub status @Dev
  echo htd:dev:E$?:$# $* >&2

  test $# -gt 0 || set -- list
  test $# -gt 1 && {
    t=${2:?Expected topic tag}
    #htd__dev tag-exists && {
    #  htd__dev note-exists &&
    #}
  }
  case "${1:-}" in


    ( note ) # ~ <Topic>
        : "${t:?Expected topic tag}"
        lib_require ctx-htd && INIT_LOG=$LOG lib_init $lib_loaded || return
        create idx StatTab ${HTDIR:?}/.meta/stat/index/context-dev.list &&
        $idx.fetch devtag "$t" &&
        @Dev $devtag.edit-notes ;;

    ( list )
      ;;
  esac
}

#
