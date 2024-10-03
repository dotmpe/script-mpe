#!/usr/bin/env bash

set -e
set -u
set -o pipefail

true "${blocksize:="1M"}"
true "${blocksize:="100k"}"
true "${count:="1k"}"

# Using a RAM disk helps with throughput, but not much or anything at all to
# lower latency with many small files. Here a 100MB file takes .3 seconds to
# write to disk, and .2s to write to RAM disk.

sid=$(uuidgen)
key="script-htd-$sid"
tmpf_mem="$RAM_TMPDIR/$key"
tmpf="$TMPDIR/$key"
tmpf2="$HOME/.local/tmp/$key"

mkdir -p $RAM_TMPDIR $HOME/.local/tmp

echo '------------------------------------------------------------------------'
time sh -c "dd if=/dev/zero of=$tmpf.bm bs=$blocksize count=$count && sync"
du -hs $tmpf.bm
rm -f $tmpf.bm

echo '------------------------------------------------------------------------'
time sh -c "dd if=/dev/zero of=$tmpf2.bm bs=$blocksize count=$count && sync"
du -hs $tmpf2.bm
rm -f $tmpf2.bm

echo '------------------------------------------------------------------------'
time sh -c "dd if=/dev/zero of=$tmpf_mem.bm bs=$blocksize count=$count && sync"
du -hs $tmpf_mem.bm
rm -f $tmpf_mem.bm

exit $?
