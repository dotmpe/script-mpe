#!/bin/sh
htd_man_1__urlstat='Build urlstat index

  list [Glob]
    List entries
  urllist ? [Stat-Tab]
    List URI-Refs, see htd urls for other URL listing cmds.
  entry-exists URI-Ref [Stat-Tab]
  check [--update] [--process]
    Add missing entries, update only if default stats changed. To update stat
    or other descriptor fields, or (re)process for new field values set option.
  checkall [-|URI-Refs]...
    Run check
  updateall
    See `htd checkall --update`
  processall
    See `htd checkall --process --update`
'

urlstat__help ()
{
  echo "$htd_man_1__urlstat"
}
