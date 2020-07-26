#!/bin/sh

htd_man_1__scrtab='Build scrtab index

  new [NAME] [CMD]
    Create a new SCR-Id, if name is a file move it to the SCR dir (ignore CMD).
    If CMD is given for name, create SCR dir script. Else use as literal cmd.
  list [Glob]
    List entries
  scrlist ? [Stat-Tab]
    List SCR-Ids
  entry-exists SCR-Id [Stat-Tab]
  check [--update] [--process]
    Add missing entries, update only if default tabs changed. To update tab
    or other descriptor fields, or (re)process for new field values set option.
  checkall [-|SCR-Ids]...
    Run check
  updateall
    See `htd checkall --update`
  processall
    See `htd checkall --process --update`
'
htd__scrtab()
{
  eval set -- $(lines_to_args "$arguments") # Remove options from args
  subcmd_default=list subcmd_prefs=scrtab_\ htd_scrtab_ try_subcmd_prefixes "$@"
}
htd_flags__scrtab=qliAO


scrtab__help()
{
  std_help scrtab
}

#
