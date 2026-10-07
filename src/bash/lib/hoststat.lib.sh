#!/bin/sh


hoststat_lib__load()
{
  hstdir=$HOME/htdocs/.build/stat/host/
  mkdir -p $hstdir
}

htd_hoststat_ping()
{
  test -n "$failed" || error "detect-ping expects failed env" 1
  while test $# -gt 0
  do
    ping -qt 1 -c 1 $1 >/dev/null &&
      stderr ok "$1" || echo "hoststat:ping:$1" >$failed
    shift
  done
  test ! -s "$failed"
}

htd_hoststat_status()
{
  for stat_po in $hstdir/*.ping-online $hstdir/*.ping-offline
  do
    test -e "$stat_po" || continue

    fnmatch "*.ping-offline" "$stat_po" && {
        name=$(basename "$stat_po" .ping-offline)
        echo "$name (offline)"
        continue
    }

    name=$(basename "$stat_po" .ping-online)
    echo $name
  done
}

htd_hoststat_update()
{
  local addr=
  while test $# -gt 0
  do
    addr=$1
    host "$1" >/dev/null 2>&1 || {
        addr="$( ssh -G $1 | awk '/^hostname / { print $2 }' )"
    }
    host "$addr" >/dev/null || return $?

    htd_hoststat_ping "$addr" && {

      touch $hstdir/$1.ping-online
    } || {

      touch $hstdir/$1.ping-offline
    }
    shift
  done
}
