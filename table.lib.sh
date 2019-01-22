#!/bin/sh

# Deal with simple whitespace formatted tables


# fixed-table-hd-offset HD FIRSTHD TAB
# Returns header char offset given header key, first header key and file-name.
# The first header key's offset is set to 0 regardless of its real displacement.
# For subsequent fields the exact columns to the left is printed.
fixed_table_hd_offset()
{
  test -n "$1" || set -- HD "$2" "$3"
  test -n "$2" || set -- "$1" FIRSTHD "$3"
  test -n "$3" || error "table expected" 1
  test -e "$3" || error "table expected: $3" 1
  # correct for first col, or for line-end

  test "$1" = "$2" \
    && echo 0 \
    || echo $($ggrep -m 1 -E '^# ?'$2' [^\!\/\.,]+$' $3 |
        $gsed -E 's/^(.*)\ \<'$1'\>( .*|$)/\1/g' | wc -c)
}

# fixed_table_hd_offsets TAB HD...
# Given file with tabulated header and a list of header keys, print all
# field/column offsets.
fixed_table_hd_offsets()
{
  local tab=$1 fc=$2
  shift
  while test ${#@} -gt 0
    do
      fixed_table_hd_offset $1 $fc $tab
      shift
    done
}

# Create a file with arguments for the posix `cut` command, to split each
# tabulated line into its separate column fields.
fixed_table_hd_cuts() # Tab Colds...
{
  local tab=$1 fc=$2 offset= lc= old_offset=
  shift
  while test ${#@} -gt 0
    do
      offset=$(fixed_table_hd_offset $1 $fc $tab)
      test -n "$old_offset" && {
        echo "$lc -c$(( $old_offset + 1 ))-$offset"
      }
      lc=$1
      old_offset=$offset
      shift
    done
    echo "$lc -c$(( $old_offset + 1 ))-"
}

fixed_table_cuts()
{
  local colh=$1 dsp=$2
  shift 2
  while test ${#@} -gt 0
  do
    test -n "$old_offset" && {
      echo "$colh -c$(( $old_offset + 1 ))-$dsp"
    }
    old_offset=$dsp
    colh=$1
    dsp=$2
    shift 2
  done
  echo "$colh -c$(( $old_offset + 1 ))-"
}

# Find first unix-y comment-line and use as table headers. Ignore bashbang or
# any pre-proc directive without leading space, and any lines with period(s)
grep_list_head()
{
  list_head_line="$($ggrep -E -m 1 '^#\ ?[^!\/\.]+$' "$1")" || return
  echo "$list_head_line" | $gsed -E 's/^\s*# ?//g'
}

fixed_table_hd_ids()
{
  echo $( grep_list_head "$1" )
}

# Build cut-file
fixed_table_cuthd()
{
  cutf="$(dirname "$1")/$(basename "$1" .tab).cuthd"
  test -e "$cutf" -a "$cutf" -nt "$1" || {
    { echo "# COLVAR CUTFLAG"
      fixed_table_hd_cuts "$@"
    } >$cutf
  }
}

# Given `cut` arguments file for the file, read each line and fields.
# Prints a single line of var declarations for each record/line in table file.
# Passing an existing `cut` arguments file allows to read tables w/o header,
# e.g. to parse record lines stripped from comments on stdin.
# Note: trouble is many shell regulars (ps, lsof) have an addiitional alignment
# on the headers that precludes using the standard header parsing provided here
# and makes providing `cut` arguments based on the header row more cumbersome.
# See htd proc.
fixed_table()
{
  test -e "$1" -o "$1" = "-" || error "fixed-table Table file expected" 1
  local tab="$1" cutf=
  test -n "$2" -a -e "$2" && cutf="$2" || {
    # Get headers from first comment if not given
    test -n "$2" || {
      test -n "$fields" || fields="$(fixed_table_hd_ids "$1")"
      set -- "$1" "$fields"
    }
    # Assemble COLID CUTFLAG table (if missing or stale)
    fixed_table_cuthd "$@"
  }
  # expand contained code, var references on eval
  upper=0 default_env expand 1
  trueish "$expand" && _q='\\"' || _q='\'\'
  # Walk over rows, columns and assemble Sh vars, include raw-src in $line
  local row_nr=0
  grep -v '^\s*\(#.*\)\?$' "$tab" | while read line
  do
    row_nr=$(( $row_nr + 1 ))
    cat "$cutf" | grep -v '^\s*\(#.*\)\?$' | while read col args
      do
        printf " $col=$_q$(echo $(echo "$line" | cut $args) | sed 's/[%]/&/g')$_q "
      done
      printf " row_nr=$row_nr "
      printf " line=$_q$(echo "$line" | sed 's/[%]/&/g')$_q "
      echo
  done
}
