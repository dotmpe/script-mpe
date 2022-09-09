#!/bin/sh
htd_man_1__docstat='Build docstat index from local documents

    exists - Check entry exists for document
    extdescr -  Update status descriptor bits of entry
    extitle -  Update title of entry
    extags - Update tags for entry
    ptags - Reset primary tag

    proc - Run processor for single document
    check - Check, update entry for single document
    update - Refresh entry for single document w/o check

    err - List entries with non-zero status
    ok - List entries with zero status

    procall - Process all documents
    addall - Check index for all documents
    info-local - Fetch/parse every entry and print fields for local files
    run - Run any other sub-command for each doc [default: proc]
    list [GLOB] - Print all or matching entries
    count

    check
    info
    checkidx - Slow duplicate index check

    taglist - update and list tag.list from docstat.tab

htd docstat uses plumbing functions from docstat.lib directly, there are no
subcmd handlers beyond htd:docstat.

proc(all),addall/check,info-local all take a local list of document files and
run a function for each filename.

check, info all read docstat items at stdin, parse that, and do their thing.
'

htd__docstat()
{
  test -n "$1" || set -- list
  subcmd_prefs=docstat_ try_subcmd_prefixes "$@"
}
htd_flags__docstat=ql
htd_libs__docstat=str\ date\ statusdir\ ctx-doc\ doc\ prefix\ du\ match-htd

docstat_help ()
{
  echo "$htd_man_1__docstat"
}
