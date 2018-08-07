#!/bin/sh


# Resolve line span (start line - line count)
edl_resolve_lines()
{
  test -n "$3" || set -- "$1" "$2" "1"
  head -n $2 "$1" | tail -n $3
}

resolve_line_range()
{
  resolve_lines "$1" "$2" "$(( $3 - $2 + 1 ))"
}

# Resolve character span
resolve_chars()
{
  echo TODO edl.lib:resolve-chars
}

# Resolve character start to end pos
resolve_char_range()
{
  resolve_chars "$1" "$2" "$(( $3 - $2 + 1 ))"
}

resolve_line_chars()
{
  cut -c$1-$2
}

resolve_line_char_range()
{
  resolve_line_chars "$1" "$2" "$(( $3 - $2 + 1 ))"
}

# <1-prefix>
# <2-file>
# <3-line-span>
# <4-descr-span>
# <5-descr-line-offset-span>
# <6-cmnt-span>
# <7-cmnt-line-offset-span>


#radical.py --issue-format=full-sh vc.sh | grep -v '^\s*$' | tq.py vc.sh

