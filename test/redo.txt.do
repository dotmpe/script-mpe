last_arg="$_"
#redo-ifchange "./$1.do"
test -e "$1" && {

  # NOTE: to not update with redo, output current contents exactly
  cat "$1"

} || {
  echo Prev-Last-Arg: \"$last_arg\"
  echo Redo-Run-Id: $REDO_RUNID
  echo Shell: \"$SHELL\"
  echo Arg-Cnt: $#
  echo Args: \"$*\"
  echo Proc-Id: $$
  echo 'Redo-Env: |'
  env | grep -i '\(_\|\<\)redo\(_\|\>\)' | sed 's/^/    /g'
  echo 'Env: |'
  env | sed 's/^/    /g'
  echo "# vim:ft=yaml:nowrap:"
}
