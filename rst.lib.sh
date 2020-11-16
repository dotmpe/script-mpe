#!/bin/sh

# Get first line if second line is all title adoration.
# FIXME: this misses rSt with non-content stuff required before title, ie.
# replacement roles, includes for roles, refs etc.
rst_doc_title()
{
  rst_content_firstline "$1"
  head -n $(( $firstline_nr + 1 )) "$1" | tail -n 1 | $ggrep -qe "^[=\"\'+~_-]\+$" || return 1
  head -n $firstline_nr "$1" | tail -n 1
}

rst_content_firstline ()
{
  local line l=0
  while read -r line
  do
    l=$(( $l + 1 ))
    echo "$line" | grep -q '^\s*$\|^\s*:\|^\s*\.\.\ ' && continue
    firstline="$line"
    break
  done <"$1"
  firstline_nr=$l
}

rst_docinfo() # Document Fieldname
{
  # Get field value (including any ':'), w.o. leading space.
  # No further normalization.
  $ggrep -m 1 -i '^\:'"$2"'\:.*$' "$1" | cut -d ':' -f 3- | cut -c2-
}

rst_docinfo_date() # Document Fieldname
{
  local dt="$(rst_docinfo "$@" | normalize_ws_str)"
  test -n "$dt" || return 1
  fnmatch "* *" "$dt" && {
    # TODO: parse various date formats
    error "Single datetime str required at '$1': '$dt'"
    return 1
  }
  echo "$dt"
}

rst_doc_date_fields() # Document Fields...
{
  local rst_doc="$1" ; shift
  rst_docinfo_inner() {
    rst_docinfo_date "$rst_doc" "$1" || echo "-"
  }
  act=rst_docinfo_inner foreach_do "$@"
}

# Look for single-line reference definitions,
# list parts tab-separated: <filename> <linenr> ( <label> | <anonymous> ) <ref>
rst_reference_definitions ()
{
  git grep -Hn '^ *\.\. _.*:\ ' '*.rst' |
    sed 's/^\(.*\):\([0-9]\+\):\s*\.\.\s_`\?\([^`]\+\)`\?:\s\+/\1\t\2\t\3\t/'
}

# Look for (single-line, unbroken/wrapped) inline rST references, list parts
# tab-separated: <filename> <linenr> <label> '<'<uriref>'>' <anonymous>
rst_reference_inlines ()
{
  test $# -gt 0 || set -- '*.rst'
  local path; for path in $( vc_tracked "$@" )
  do
    grep -oHn '`[^`]\+\s\+<[^`>]\+>`__\?\|[a-zA-Z0-9_-]\+_' "$path" || continue
  done |
    grep -v '^[^:]*:[0-9]\+:_\+$' | # Drop all-underscore lines
    sed 's/^\(.*\):\([0-9]\+\):`\?\([^`]\+\)\(<[^>]\+>\)\?`\?_\(_\)\?$/\1\t\2\t\3\t\4\t\5/g'
}

# Look for explicit targets definitions
rst_reference_targets ()
{
  git grep -Hn '^ *\.\. _.*:\ *$' '*.rst'
}

#
