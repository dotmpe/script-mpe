#!/bin/sh
set -e

# memcached through membash is unfortunately by far the slowest.

# As for redis, it is as much as twice as slow as filesystem access,
# and for this filesize it seems there's no difference for RAM or disk storage.

count=100
data="$(cat .package.sh)"
sid=$(uuidgen)
key="script-htd-$sid"
tmpf_mem="$RAM_TMPDIR/$key"
tmpf="$TMPDIR/$key"
tmpf="$HOME/.tmp/$key"
mkdir -p $(dirname $tmpf) $(dirname $tmpf_mem)
echo sid=$sid key=$key tmpf=$tmpf tmpf_mem=$tmpf_mem
echo

echo File write
time ( for x in $(seq 0 $count)
do
  echo "$data" > $tmpf
done 2>&1 >/dev/null )

echo File read
time ( for x in $(seq 0 $count)
do
  cat "$tmpf" | grep _id >/dev/null
  #2>&1
done 2>&1 >/dev/null )

echo '------------------------------------------------------------------------'
echo RAM write
time ( for x in $(seq 0 $count)
do
  echo "$data" > $tmpf_mem
done 2>&1 >/dev/null )

echo RAM read
time ( for x in $(seq 0 $count)
do
  cat "$tmpf_mem" | grep _id >/dev/null
  #2>&1
done 2>&1 >/dev/null )
echo '------------------------------------------------------------------------'
echo Redis write
#redis-cli set $key "$data"
time ( for x in $(seq 0 $count)
do
  redis-cli set $key "$data" >/dev/null
done 2>&1 >/dev/null )

echo Redis read
time ( for x in $(seq 0 $count)
do
  redis-cli get $key >/dev/null
done 2>&1 >/dev/null )

echo

echo Memcache write
time ( for x in $(seq 0 $count)
do
  membash set "$key" 60 "$data"
done 2>&1 >/dev/null )

echo Memcache read
time ( for x in $(seq 0 $count)
do
  membash get "$key" >/dev/null
done 2>&1 >/dev/null )
