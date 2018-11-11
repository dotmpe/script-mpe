#!/bin/sh

context_lib_load()
{
  test -n "$STATUSDIR_ROOT" || STATUSDIR_ROOT=$HOME/.statusdir
  test -n "$HTDCTX_TAB" || HTDCTX_TAB=${STATUSDIR_ROOT}/index/htdcontext.tab
  test -e "$HTDCTX_TAB" || {
    touch "$HTDCTX_TAB" || return $?
  }
}


context_list()
{
  test -n "$context_list" || context_list="$HTDCTX_TAB"

  grep -q '^#include\ ' "$context_list" && {
    expand_preproc include "$context_list" | grep -Ev '^\s*(#.*|\s*)$'
  } || {
    read_nix_style_file "$context_list"
  }
}

# Compile and match grep for tag with Ctx-Table
context_exists() # Tag
{
  p_="$(match_grep "$1")" ; grep_fl=-q
  $ggrep $grep_fl "^[0-9 -]*\b$p_\\ " "$HTDCTX_TAB"
}

# Compile and match grep for tag in Ctx-Table, case insensitive
context_existsi() # Tag
{
  p_="$(match_grep "$1")" ; grep_fl=-qi
  $ggrep $grep_fl "^[0-9a-z -]*\b$p_\\ " "$HTDCTX_TAB"
}

# Compile and match grep for sub-tag in Ctx-Table
context_existsub()
{
  p_="$(match_grep "$1")" ; grep_fl=-qi
  $ggrep $grep_fl "^[0-9a-z -]*\b[^ ]*\/$p_\\ " "$HTDCTX_TAB"
}


# TODO: retrieve tag from default, or all NS
context_tag()
{
  test -n "$NS" -a -n "$1" || error "tag: NS and arg:1 expected" 1
  $ggrep -n -m 1 "^[0-9a-z -]*\b$NS$1\\ " "$HTDCTX_TAB"
}

# Return record for given ctx tag-id
context_tag_entry()
{
  #test -n "$NS" -a -n "$1" || error "tag-entry: NS and arg:1 expected" 1
  p_="$(match_grep "$1")"
  $ggrep -n -m 1 "^[0-9a-z -]*\b$p_\\ " "$HTDCTX_TAB"
}

# Return record for given
context_subtag_entries()
{
  #test -n "$NS" -a -n "$1" || error "tag-entry: NS and arg:1 expected" 1
  p_="$(match_grep "$1")"
  $ggrep -n -m 1 "^[0-9a-z -]*\b[^ ]*\/$p_\\ " "$HTDCTX_TAB"
}

context_parse()
{
  # Split grep-line number from rest
  line="$(echo "$1" | cut -d ':' -f 1)"
  rest="$(echo "$1" | cut -d ':' -f 2-)"
  export line rest

  # Split rest into three parts (see docstat format), first stat descriptor part
  stat="$(echo "$rest" | grep -o '^[^_A-Za-z]*' )"
  rest="$(echo "$rest" | sed 's/[^_A-Za-z]*//' )"

  tagid="$(echo "$rest" | cut -d ' ' -f 1)"
  export stat tagid rest
}

# XXX: docs
context_tag_env()
{
  context_parse "$( context_tag_entry "$1" )"
}
context_subtag_env()
{
  context_parse "$( context_subtag_entries "$1" )"
}
context_tag_init()
{
  context_tag_fields_init | normalize_ws >> "$HTDCTX_TAB"
}
context_tag_fields_init()
{
  date +'%Y-%m-%d'
  echo "$tagid"
}
