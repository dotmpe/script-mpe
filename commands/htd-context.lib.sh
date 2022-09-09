#!/bin/sh

htd_man_1__context='Track oneline records.

  list
  roots-docstat
    TODO: see docstat taglist
  check TAGS...
    See that tag exists with correct case and not as sub-tag.
  new
    TODO: add context records
  update
  start close destroy
    XXX: sessions
  tree
    XXX: see txt.py txtstat-tree
  summary
    count lines
  all-tags TAG
    Show all related tags (through context.tab) for given tag.
  super-order TAG
  super-orders TAGS...
    Resolve super: meta-field starting at TAG until the root and list.

User-Conf

  tagref-libs TAGREFS...
    Show <tag>:<sid>:<lib-path> for given tags.

Plumbing
  file
    Show context.tab value, usually the root file in STATUSDIR_ROOT
    (default $CTX_TAB)
  files
    List root and includes recursively as raw reference and resolved pathname.
  tab
    List all context records, starting at root file and repleacing every
    include-directive with actual file contents.
  tag-list
    List only the context name IDs from context.tab.
  env-list [FMT]
    Various printouts of current context environment (CTX/CTXP, etc).
    Formats: env, tags, online and libids. (This only useful for exported env.)
  exists-tag TAG
    Silent tag-exists check.
  exists-tagi TAG
    Case insensitive exists-check.
  exists-subtagi SUBTAG
    Silent subtag-exists check.
  url-entry URL
    Show single record with matching <URL> attribute.
'
htd__context()
{
  test -n "$1" || set -- list
  subcmd_prefs=${base}_context_\ context_ try_subcmd_prefixes "$@"
}
htd_flags__context=l
htd_libs__context="match match-htd statusdir src src-htd str-htd list prefix context context-uc"

# Use docstat built-in to retrieve cached tag list
htd_context_list()
{
  lib_require docstat || return
  docstat_taglist | $gsed 's/^[0-9 -]*\([^ ]*\).*$/\1/g'
}

# Filter docstat cached tag list for context containing '/'
htd_context_roots_docstat()
{
  docstat_taglist | $gsed 's/@\([^@/]*\).*/\1/g' | sort -u
}

# Check that given context names exist, either as root or sub-context
htd_context_check () # TAGS...
{
  test -n "$*" || warn "Arguments expected" 1 || return
  context_check "$@"
}

# Initialize Ctx-Table line for given context
htd_context_new()
{
  fnmatch "*/*" "$1" && {
    htd_context_new "$(dirname "$1" )"
  }
  context_exists "$1" && return 1
  context_parse "0: - $1"
  context_tag_new
}

# Other context actions

#htd_context_update()
#{
#  true
#}
#
#htd_context_start()
#{
#  echo TODO: start
#}
#
#htd_context_close()
#{
#  echo TODO: close
#}
#
#htd_context_destroy()
#{
#  echo TODO: destroy
#}

htd_context_tree()
{
  txt.py txtstat-tree "$CTX_TAB"
}

htd_context_summary ()
{
  CTX_CNT=$(context_tab | count_lines)

  $LOG header2 "Contexts" "" "$CTX_CNT"
}

#
