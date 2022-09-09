#!/bin/bash

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
  test $# -eq 1 || return
  test -n "$1" || return
  case "$1" in
    [Oo]n|[Tt]rue|[Yyj]|[Yy]es|1 )
      return 0;;
    * )
      return 1;;
  esac
}
# Sh-Copy: HT:tools/u-s/parts/trueish.inc.sh

fnmatch()
{
  test $# -eq 2 || return
  case "$2" in
    $1 ) return 0 ;;
    *) return 1 ;;
  esac
}
# Sh-Copy: HT:tools/u-s/parts/trueish.inc.sh

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

get_uuid()
{
  test -e /proc/sys/kernel/random/uuid && {
    cat /proc/sys/kernel/random/uuid
    return 0
  }
  test -x $(which uuidgen) && {
    uuidgen
    return 0
  }
  error "FIXME uuid required" 1
  return 1
}

tmpd()
{
  tmpd=$BATS_TMPDIR/bats-tempd-$(get_uuid)
  test ! -d "$tmpd" || return
  mkdir -vp "$tmpd"
}

file_equal()
{
  sum1=$(md5sum $1 | cut -f 1 -d' ')
  sum2=$(md5sum $2 | cut -f 1 -d' ')
  test "$sum1" = "$sum2" || return 1
}
