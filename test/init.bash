load helper

# Set env and other per-specfile init
test_init()
{
  test -n "$base" || exit 12
  test -n "$uname" || uname=$(uname)
  test -n "$scriptpath" || scriptpath=$(pwd -P)
  hostname_init
}

hostname_init()
{
  hostnameid="$(hostname -s | tr 'A-Z.-' 'a-z__')"
}

init()
{
  test_init

  test -x $base && {
    bin=$scriptpath/$base
  }
  lib=$scriptpath

  __load_mode=load-ext . $scriptpath/util.sh
  lib_load os sys str std main

  return # FIXME: cleanup rest

  # init script env
  test -n "$ENV_NAME" && {
    # TODO: require (prim.) source file for env
    # test -n "$ENV" || error "Expected ENV profile for $ENV_NAME" 1
    printf -- " "
  } || {
    export SCR_SYS_SH=bash-sh
    export ENV_NAME=testing
    export ENV=./tools/sh/env.sh
  }

  # older script-mpe init
  #main_init

  test -n "$TMPDIR" || error TMPDIR 1

  case "$uname" in Darwin )
      export TMPDIR=$(cd $TMPDIR; pwd -P)
      export BATS_TMPDIR=$(cd $BATS_TMPDIR; pwd -P)
    ;;
  esac

  ## XXX does this overwrite bats load?
  #. main.init.sh

  export verbosity=
}


### Helpers for conditional tests

# TODO: SCRIPT-MPE-2 deprecate in favor of require-env from projectenv.lib
# Returns successful if given key is not marked as skipped in the env
# Specifically return 1 for not-skipped, unless $1_SKIP evaluates to non-empty.
is_skipped()
{
  local skipped="$(echo $(eval echo \$$(get_key "$1")_SKIP))"
  test -n "$skipped" && return
  return 1
}

# XXX: SCRIPT-MPE-2 Hardcorded list of test envs, for use as is-skipped key
current_test_env()
{
  test -n "$TEST_ENV" \
    && echo $TEST_ENV \
    || case $hostnameid in
      simza | boreas | vs1 | dandy | precise64 ) hostname -s | tr 'A-Z' 'a-z';;
      * ) whoami ;;
    esac
}

# Check if test is skipped. Currently works based on hostname and above values.
check_skipped_envs()
{
  test -n "$1" || return 1
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

# TODO: require-env, prepare-env. Prepare env needs to expand tags to all
# implied tags, ie. expand-item LIST ID IMPLIED


# Deprecate many of below too, see str.lib.sh mk*id instead

get_key()
{
  local key="$(echo "$1" | tr 'a-z._-' 'A-Z___')"
  fnmatch "[0-9]*" "$key" && key=_$key
  echo $key
}

trueish()
{
  test -n "$1" || return 1
  case "$1" in
    [Oo]n|[Tt]rue|[Yyj]|[Yy]es|1 )
      return 0;;
    * )
      return 1;;
  esac
}

fnmatch()
{
  case "$2" in $1 ) return 0 ;; *) return 1 ;; esac
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
  # XXX: cleanup
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
  tmpd=$BATS_TMPDIR/bats-tempd-$(get_uuid)
  test -d "$tmpd" && rm -rf $tmpd
  mkdir -vp $tmpd
}

file_equal()
{
  sum1=$(md5sum $1 | cut -f 1 -d' ')
  sum2=$(md5sum $2 | cut -f 1 -d' ')
  test "$sum1" = "$sum2" || return 1
}

