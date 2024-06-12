# Leaves vars 'fname' and 'fres' upon matches (first file). Return 1 on no matches.
grep_var_files () # [Var-pref] ~ <Grep-expr> <Var-keys...>
{
  local grep="$1" fvkey fvar
  shift
  while test $# -gt 0
  do
    fname=$1
    fvkey="${1//-/_}"
    fvar=${var_pref:?}${fvkey^^}
    : "${!fvar:?"$(sys_exc grep:var:files:$fvar)"}" &&
    fr=$(grep " $grep " "$_") && return
    shift
  done
  return 1
}

merge_unique_lines () # [(stdin)] ~ <Source> <Dest>
{
  local arg tmpf outf
  tmpf=/tmp/unique-lines-$RANDOM.tmp
  outf=/tmp/unique-lines-$RANDOM.out
  for arg in "$@"
  do
    test "$arg" = "-" && {
      remove_dupes >>"$outf"
    } || {
      remove_dupes < "$arg" >>"$outf"
    }
    cp "$outf" "$tmpf"
    remove_dupes < "$tmpf" >"$outf"
  done
  test "${2:--}" = "-" && {
    cat "$outf"
  } || {
    cat "$outf" >"$2"
  }
  rm "$tmpf" "$outf"
}
