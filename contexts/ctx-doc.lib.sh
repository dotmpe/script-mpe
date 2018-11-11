#!/bin/sh

ctx_doc_lib_load()
{
  lib_load ctx-std ctx-thing ctx-item
}

docstat_init_doc_descr()
{
  docstat_init_std_descr
  test -e "$docstat_src" && {
    rst_doc_date_fields "$docstat_src" created updated closed destroyed
  } || {
    echo "- - -"
  }
  echo "-"
}

docstat_parse_doc_descr()
{
  docstat_parse_std_descr "$@"
  test $# -gt 2 || return 0
  shift 2 && docstat_parse_item_descr "$@"
}
