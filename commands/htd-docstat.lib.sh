#!/bin/sh
htd_man_1__docstat='Build docstat index from local documents

    proc - Run processor for single document
    check - Check, update entry for single document
    update - Refresh entry for single document w/o check
    extdescr -  Update status descriptor bits of entry
    extitle -  Update title of entry
    extags - Update tags for entry
    ptags - Reset primary tag

    procall - Process all documents
    addall - Check index for all documents
    run - Run any other sub-command for each doc

    checkidx - Slow duplicate index check
    taglist - updat taglist from index
'

htd__docstat()
{
  test -n "$1" || set -- list
  doc_lib_init
  subcmd_prefs=docstat_ try_subcmd_prefixes "$@"
}
htd_run__docstat=ql
htd_libs__docstat=str\ date\ statusdir\ docstat\ htd-docstat\ ctx-doc\ doc

docstat__help ()
{
  echo "$htd_man_1__docstat"
}
