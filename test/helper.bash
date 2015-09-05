
test -z "$PREFIX" && bin=$base || bin=$PREFIX/bin/$base


next_temp_file()
{
  test -n "$pref" || pref=script-mpe-test-
  local cnt=$(echo $(echo /tmp/${pref}* | wc -l) | cut -d ' ' -f 1)
  next_temp_file=/tmp/$pref$cnt
}
lines_to_file()
{
  test -n "$file" || next_temp_file
  local line_out
  echo "# test/helper.bash $(date)" > $next_temp_file
  for line_out in "${lines[@]}"
  do
    echo $line_out >> $next_temp_file
  done
}
