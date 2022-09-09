#!/bin/sh

ctx_doc_lib_load()
{
  lib_require ctx-std ctx-thing ctx-item
}

docstat_init_doc_descr()
{
  docstat_init_std_descr # status, filemtime
  test -e "$docstat_src" && {
    # Get from docinfo field
    rst_doc_date_fields "$docstat_src" created updated closed destroyed
    return
  } || {
    echo "- - - -"
  }
}

docstat_parse_doc_descr()
{
  docstat_parse_std_descr "$1" "$2" || return
  test $# -gt 2 || return 0
  shift 2 && docstat_parse_item_descr "$@"
}
