#!/bin/sh

# de-normalize outline with shell-cmd specs; ie. join into complete cmd lines.
#
# To manage variable depth, line markers are inserted that effectively lead
# a group with specific spec, and when returning from a nested group to a
# previous layer.
#
sh_spec_outline()
{
  local indent_d= var_d= spec_d= done= c=0

  push()
  {
    test -z "$indent_d" && indent_d="$1" || indent_d="$1 $indent_d"
    c=$(( $c + 1 ))
    $OUT "# start $1"
  }

  back()
  {
    test -z "$indent_d" && last_indent=0 ||
      last_indent="$(printf %s "$indent_d" | cut -f 1 -d' ')"
  }

  pop()
  {
    test "$c" = "1" && indent_d= ||
      indent_d="$(printf %s "$indent_d" | cut -f 2- -d' ')"
    c=$(( $c - 1 ))
    back
  }

  pop_until()
  {
    $OUT "# end $indent"
    while test $1 -lt $last_indent
    do
      pop
      $OUT "# end $last_indent"
      test $c -gt 0 || break
    done
  }

  until test -n "$done"
  do
    IFS= read line || done=1

    test -z "$done" || {

      $OUT "$last_line"
      unset last_line
      $OUT "# end $indent"
      while test $last_indent -gt 0
      do
        pop
        $OUT "# end $last_indent"
        test $c -gt 0 || break
      done
      break
    }

    sh_spec_parse_indent "$line"

    test "$indent" = "$last_indent" && {

      $OUT "$last_line"
      last_line=$line
      continue
    }

    test $indent -gt $last_indent && {

      $OUT "$last_line"
      push "$indent"

    } || {

# XXX: cleanup sh-spec-outline
      #test $indent -lt $last_indent && {
      $OUT "$last_line"
      $OUT "# end $last_indent"

      #$OUT "# 1.end $last_indent '$indent_d' new:$indent"
      #pop
      #pop_until "$indent"
      #}
    }

    last_line=$line

    #fnmatch "*;*" "$line" && {

    #  for spec in $(echo "$line" | tr ';' ' ' )
    #  do
    #    sh_spec_outline_vspec "$spec"
    #  done

    #} || {

    #  sh_spec_outline_vspec "$line"
    #}

    #echo "$spec_d; $var_d"
    #echo "'$var_d;' '$spec_d'"
    #echo "${indent_}${line}"
  done
}

sh_spec_outline_vspec()
{
  { fnmatch "*;*" "$1"; }||{
      fnmatch "*=*" "$1"&&{ var_d="$var_d $1"; return; }
  }

  fnmatch "*;" "$spec_d"&&{ spec_d="$spec_d $1"; }||{ spec_d="$spec_d; $1"; }
}

fnmatch() { case "$2" in $1 ) return ;; * ) return 1 ;; esac; }

# Set indent to nr. of spaces leading SPEC
sh_spec_parse_indent() # SPEC
{
  test $# -eq 1 || return
  local indent_="$( printf %s "$1" | sed 's/^\([ ]*\).*$/\1/' )"
  test -n "$indent_" && indent="${#indent_}" || indent=0
}

# Read input as file lines. Combine varspec-cmdspec.
# Ignore empty or unixy comments, TODO: trueish pass-trough
# to relay unparsed lines as is to out.
sh_spec_table() # [varspec-width] [pass-through]
{
  test $# -eq 1 || return

  local done= ln=0 ind_d= ind_lvl=0 \
    new_cmdspec= new_varspec= \
    varspec= last_varspec= varspec_d= varspec_lvl=0 \
    cmdspec= last_cmdspec= \
    indent= last_indent=

  sh_new_stack ind
  sh_new_stack varspec

  TAB_C="	"

  # Insert tab-character at x position (awk)
  awk -vFS="" -vOFS="" '{$'$1='$'$1'"\t"}1' |

  # Read lines
  until test -n "$done"
  do
    IFS=$TAB_C read new_varspec new_cmdspec || done=1

    sh_spec_table_inner || return
  done
}

sh_spec_table_inner()
{
  # Flush and break read-loop on EOF
  test -z "$done" || {
    # Output last line if any
    sh_spec_d_out "$last_varspec" "$last_cmdspec"

    $OUT "# Read $ln lines"
    unset ind_lvl ln
    return
  }

  fnmatch "`printf "\\t"`*" "$new_varspec" &&
    $LOG warn "$ln" "Whitespace not tabs please" "line:$ln"

  # Parse as normal line.
  sh_spec_parse_indent "$new_varspec"
  new_varspec="$(echo $new_varspec)"

  # Init indent on first run
  test -n "$last_indent" || last_indent=$indent

  test -z "$last_varspec" -o $indent -gt $last_indent || {
    test -z "$DEBUG" || {
      $LOG note "$ln" "now" "$new_varspec; $new_cmdspec"
      $LOG note "$ln" "last" "$last_varspec; $last_cmdspec"
    }

    sh_spec_d_out "$last_varspec" "$last_cmdspec"
  }

  test $indent -gt $last_indent && { {

      ind_push "$indent" && varspec_push "$new_varspec"

    } || return 11
  }

  test $indent -lt $last_indent && { {

      while test "$(ind_pop && echo "$ind")" != "$indent"
      do
        ind_pop && varspec_pop
      done
      varspec_pop && varspec_push "$new_varspec"

    } || return 12
  }

  test $indent -eq $last_indent && { {

      test -z "$ind_d" || {
        ind_pop && varspec_pop
      }
      ind_push "$indent" &&
      varspec_push "$new_varspec"

    } || return 13
  }

  # Increment line-number, and set state for next loop
  ln=$(( $ln + 1 ))

  test -z "$indent" || last_indent="$indent"
  test -z "$new_cmdspec" || last_cmdspec="$new_cmdspec"
  last_varspec="$new_varspec"
}


# Combine and output varspec-cmdspec based on varspec-c.
sh_spec_d_out() # Varspec CmdSpec
{
  test $# -eq 2 || return
  test -n "$2" || set -- "$1" "$cmdspec"

  local varexpr="$( printf %s "$varspec_d" \
    | tr '\t' '\n' \
    | $ggrep -v '^[A-Za-z_][A-Za-z0-9_]*=[^;]*$' \
    | while read varspec
    do \
      fnmatch "/*" "$varspec" \
      && printf "unset $(echo "$varspec" | cut -c2-); " \
      || {
        case "$varspec" in *";" ) printf %s "$varspec ";;
          * ) printf %s "$varspec; " ;; esac; \
      }; \
    done )"\

  local lvar="$( printf %s "$varspec_d" \
    | tr '\t' '\n' \
    | $ggrep '^[A-Za-z_][A-Za-z0-9_]*=[^;]*$' \
    | tr '\n' ' ' )"

  $OUT "$varexpr$lvar$2"
}

# Defer to line-parser based on file-name extension.
sh_spec() # File-Path
{
  test $# -gt 0 -a $# -le 2 || return
  test -f "$1" || return
  print_yellow "sh-spec" "Starting '$*'" >&2
  local specfile=$1
  shift 1

  test -n "${1:-}" || {
    local header="`head -n 1 "$specfile"`"
    test "`echo $header`" = "# varspec cmdspec #" || {
      $LOG "error" "" "No width and cannot read header" "$specfile '$header'" 1
      return 1
    }

    local width_="`printf %s "$header"| sed 's/cmdspec.*//'`"
    test -n "$width_" || $LOG "error" "" "Unable to determine width" "" 1
    set -- ${#width_}
  }

  fnmatch "*.list" "$specfile" && {
    sh-read "$specfile" | sh_spec_outline "$@"
    return $?

  } || {

    sh-read "$specfile" | sh_spec_table "$@"
  }
}

# Sync: U-S:
# Copy: user-scripts/0.0.0-dev tools/ci/parts/std-runner.sh
