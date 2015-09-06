
test -z "$PREFIX" && bin=$base || bin=$PREFIX/bin/$base



is_skipped()
{
  local key=$(echo $1 | tr 'a-z' 'A-Z')
  local skipped=$(eval echo \$${key}_SKIP)
  test -n "$skipped" && return
  return 1
}

check_skipped_envs()
{
  local skipped= envs= env=
  # XXX hardcoded envs
  test -n "$1" && envs="$1" || envs="travis jenkins berend"
  for env in $envs
  do
    is_skipped $env && {
      test "$(whoami)" = "$env" && skipped=1
      test "env $env would skip this test"
    } || continue
    
  done
  return $skipped
}

fnmatch () { case "$2" in $1) return 0 ;; *) return 1 ;; esac ; }

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

mytest_function()
{
  echo 'mytest'
}

tmpf()
{
  tmpd || return $?
  tmpf=$tmpd/$BATS_TEST_NAME-$BATS_TEST_NUMBER
  test -z "$1" || tmpf="$tmpf-$1"
}

tmpd()
{
  tmpd=$BATS_TMPDIR/bats-tempd
  mkdir -vp $tmpd
}

