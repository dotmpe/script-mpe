
# header char offset
fixed_table_hd_offset()
{
  test -n "$1" || set -- HD "$2" "$3"
  test -n "$2" || set -- "$1" FIRSTHD "$3"
  test -n "$3" || error "table expected" 1
  test -e "$3" || error "table expected: $3" 1
  # correct for first col, or for line-end
  test "$1" = "$2" \
    && echo 0 \
    || echo $(( $(grep '^#' $3 | head -n 1 |
  sed 's/^\(.*\)'$1'.*/\1/g' | wc -c) - 1 ))
}

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

fixed_table_hd_cuts()
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

# print single line of var declarations for each record in table file
fixed_table_hd()
{
  local tab=$1 cutf=$(dirname $1)/$(basename $1 .tab).cuthd
  #fixed_table_hd_offsets "$@"

  # Assemble COLID CUTFLAG table
  test $cutf -nt $1 || {
    { echo "# COLVAR CUTFLAG"
      fixed_table_hd_cuts "$@"
    } >$cutf
  }
  # Walk over rows, columns and assemble Sh vars, include raw-src in $line
  cat $tab | grep -v '^\s*\(#.*\)\?$' | while read line
  do
    cat $cutf | grep -v '^\s*\(#.*\)\?$' | while read col args
      do
        printf " $col=\"$(echo $(echo "$line" | cut $args))\" "
      done
      printf " line=\"$line\" "
      echo
  done
}


