#!/bin/sh
htd_man_1__drafts='Track drafts

'

htd__drafts()
{
  test -n "$1" || set -- list
  subcmd_prefs=htd_drafts__\ drafts_ try_subcmd_prefixes "$@"
}
#htd_flags__drafts=l
# htd_libs__drafts=str\ date\ statusdir\ ctx-doc\ doc\ prefix\ du\ match-htd

htd_drafts_help ()
{
  echo "$htd_man_1__drafts"
}

#
