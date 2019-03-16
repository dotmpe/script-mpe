#!/bin/sh

# Tag-name records wip


context_lib_load()
{
  test -n "$CTX_TAB" || CTX_TAB=${STATUSDIR_ROOT}index/context.list
  lib_assert statusdir
}

context_lib_init()
{
  test -e "$CTX_TAB" || {
    touch "$CTX_TAB" || return $?
  }
}

# Echo table after preproc
context_list()
{
  test -n "$context_list" || context_list="$CTX_TAB"

  grep -q '^#include\ ' "$context_list" && {
    expand_preproc include "$context_list" | grep -Ev '^\s*(#.*|\s*)$'
  } || {
    read_nix_style_file "$context_list"
  }
}

# Check that given tag exists. Return 0 for an exact match,
# 1 for missing, 2 for case-mismatch or 3 for sub-context exists.
# Setting case-match / match-sub to 0 / 1 resp. makes those return 0.
context_check() # [case_match=1] [match_sub=0] ~ Tag
{
  context_exists $1 && return
  context_existsi $1 && {
    true "${case_match:=1}"
    trueish "$case_match" && return 2 || return 0
  }
  context_existsub "$1" && {
    true "${match_sub:=0}"
    trueish "$match_sub" && return 0 || return 3
  }
  return 1
}

# Compile and match grep for tag with Ctx-Table
context_exists() # Tag
{
  p_="$(match_grep "$1")" ; grep_fl=-q
  context_list |
      $ggrep $grep_fl "^[0-9 -]*\b$p_\\ "
}

# Compile and match grep for tag in Ctx-Table, case insensitive
context_existsi() # Tag
{
  p_="$(match_grep "$1")" ; grep_fl=-qi
  context_list |
      $ggrep $grep_fl "^[0-9a-z -]*\b$p_\\ "
}

# Compile and match grep for sub-tag in Ctx-Table
context_existsub()
{
  p_="$(match_grep "$1")" ; grep_fl=-qi
  context_list |
      $ggrep $grep_fl "^[0-9a-z -]*\b[^ ]*\/$p_\\ "
}

# TODO: retrieve tag from default, or all NS
context_tag()
{
  test -n "$NS" -a -n "$1" || error "tag: NS and arg:1 expected" 1
  context_list |
      $ggrep -n -m 1 "^[0-9a-z -]*\b$NS$1\\ "
}

# Return record for given ctx tag-id
context_tag_entry()
{
  #test -n "$NS" -a -n "$1" || error "tag-entry: NS and arg:1 expected" 1
  p_="$(match_grep "$1")"
  context_list |
      $ggrep -n -m 1 "^[0-9a-z -]*\b$p_\\ "
}

# Return record for given ../subtag.
context_subtag_entries()
{
  #test -n "$NS" -a -n "$1" || error "tag-entry: NS and arg:1 expected" 1
  p_="$(match_grep "$1")"
  context_list |
      $ggrep -n -m 1 "^[0-9a-z -]*\b[^ ]*\/$p_\\ "
}

# Return tagged entries
context_tagged()
{
  p_="$(match_grep "$1")"
  context_list |
    $ggrep -n "^[0-9a-z -]*\b[^ ]*.*\\ \\(@\\|+\\)$p_\\(\\ \\|$\\)"
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
  context_tag_fields_init | normalize_ws >> "$CTX_TAB"
}
context_tag_fields_init()
{
  date +'%Y-%m-%d'
  echo "$tagid"
}
