
# Set env and other per-specfile init
test_init()
{
  test -n "$base" || exit 12
  test -n "$uname" || uname=$(uname)
  test -n "$scriptdir" || scriptdir=$(pwd -P)
}

init()
{
  test_init
  . ./tools/sh/init.sh

  test -x $base && {
    bin=$scriptdir/$base
  }
  lib=$scriptdir

  . $lib/main.lib.sh
  main_init

  ## XXX does this overwrite bats load?
  #. main.init.sh
}


### Helpers for conditional tests
# currently usage is to mark test as skipped or 'TODO' per test case, based on
# host. Written into the specs itself.

# XXX: Hardcorded list of test envs, for use as is-skipped key
current_test_env()
{
  test -n "$TEST_ENV" \
    && echo $TEST_ENV \
    || case $(hostname -s | tr 'A-Z' 'a-z') in
      simza | vs1 | dandy ) hostname -s | tr 'A-Z' 'a-z';;
      * ) whoami ;;
    esac
}

# Check if test is skipped. Currently works based on hostname and above values.
check_skipped_envs()
{
  test -n "$1" || return 1
  # XXX hardcoded envs
  local skipped=0
  test -n "$1" || set -- "$(hostname -s | tr 'A-Z_.-' 'a-z___')" "$(whoami)"
  cur_env=$(current_test_env)
  for env in $@
  do
    is_skipped $env && {
        test "$cur_env" = "$env" && {
            skipped=1
        }
    } || continue
  done
  return $skipped
}

# Returns successful if given key is not marked as skipped in the env
# Specifically return 1 for not-skipped, unless $1_SKIP evaluates to non-empty.
is_skipped()
{
  local key="$(echo "$1" | tr 'a-z._-' 'A-Z___')"
  local skipped="$(echo $(eval echo \$${key}_SKIP))"
  test -n "$skipped" && return
  return 1
}


### Misc. helper functions

next_temp_file()
{
  test -n "$pref" || pref=script-mpe-test-
  local cnt=$(echo $(echo /tmp/${pref}* | wc -l) | cut -d ' ' -f 1)
  next_temp_file=/tmp/$pref$cnt
}

lines_to_file()
{
  echo "status=${status}"
  echo "#lines=${#lines[@]}"
  echo "lines=${lines[*]}"
  test -n "$1" && file=$1
  test -n "$file" || { next_temp_file; file=$next_temp_file; }
  echo file=$file
  local line_out
  echo "# test/helper.bash $(date)" > $file
  for line_out in "${lines[@]}"
  do
    echo $line_out >> $file
  done
}

tmpf()
{
  tmpd || return $?
  tmpf=$tmpd/$BATS_TEST_NAME-$BATS_TEST_NUMBER
  test -z "$1" || tmpf="$tmpf-$1"
}

tmpd()
{
  tmpd=$BATS_TMPDIR/bats-tempd-$(uuidgen)
  test -d "$tmpd" && rm -rf $tmpd
  mkdir -vp $tmpd
}

file_equal()
{
  sum1=$(md5sum $1 | cut -f 1 -d' ')
  sum2=$(md5sum $2 | cut -f 1 -d' ')
  test "$sum1" = "$sum2" || return 1
}

noop()
{
  printf ""
}
