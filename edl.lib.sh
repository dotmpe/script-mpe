#!/bin/sh
# Created: 2016-12-16

# Edit Decision Lists


# Echo selected file data lines by line span (start line - line count)
edl_resolve_lines() # File Offset Length
{
  test -n "${3-}" || set -- "$1" "$2" "1"
  { tail -n "+$2" "$1" || ignore_sigpipe
  } | head -n $3
}

# Echo selected file data by character span (offset - length)
edl_resolve_chars() # File Offset Length
{
  test -n "${3-}" || set -- "$1" "$2" "1"
  { tail -c "+$2" "$1" || ignore_sigpipe
  } | head -c $3
}

edl_resolve_line_range ()
{
  edl_resolve_lines "$1" "$2" "$(( $3 - $2 + 1 ))"
}

# Resolve character start to end pos
edl_resolve_char_range()
{
  edl_resolve_chars "$1" "$2" "$(( $3 - $2 + 1 ))"
}


resolve_line_chars()
{
  cut -c$1-$2
}

resolve_line_char_range()
{
  edl_resolve_line_chars "$1" "$2" "$(( $3 - $2 + 1 ))"
}

# <1-prefix>
# <2-file>
# <3-line-span>
# <4-descr-span>
# <5-descr-line-offset-span>
# <6-cmnt-span>
# <7-cmnt-line-offset-span>
# <8-tag-span>
# <9-slug-span>
# <10-match>
