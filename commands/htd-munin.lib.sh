#!/bin/sh

htd__munin_ls()
{
  test -n "$1" || set -- $DCKR_VOL/munin/db
  tail -n +2 $1/datafile | while read dataline
  do
    hostgroup=$(echo $dataline | cut -d ':' -f 1)
    echo hostgroup=$hostgroup
    #grep -F $hostgroup $1/datafile \
    #  | sed 's#/^.*:##'

  done
  #| sort -u
}

htd__munin_ls_hosts()
{
  test -n "$1" || set -- $DCKR_VOL/munin/db
  tail -n +2 $1/datafile | while read dataline
  do echo $dataline | cut -d ':' -f 1
  done | sort -u
}

htd__munin_archive()
{
  echo TODO $subcmd
# archive selected plugins, sensor names
# 4 sets MIN/MAX/AVG values per attr:
# 5min (day), 30min (week), 2h (month), 24h (year)
# File: munin-log/2016/[02/[01/]]<group>.log.gz
# Line: <ts> <plugin> <attr>=<min>,<max>,<avg> [<attr>.*=<v>]*
#
# One backup every day, two every week, three every month, and all four very year.
}

htd__munin_merge()
{
  echo TODO $subcmd
  # rename/merge selected plugins, sensor names
}

htd__munin_volumes()
{
  local local_dckr_vol=/srv/$(readlink /srv/docker-local)

  echo /srv/docker-*-*/munin | words_to_lines | while read munin_volume
  do
    test "$local_dckr_vol/munin" = "$munin_volume" && {
      echo $munin_volume [local]
    } || {
      echo $munin_volume
    }
  done
}

# Remove stale databases, check index
htd__munin_check()
{
  test -n "$1" || set -- "$DCKR_VOL/munin/db"
  while read dataline
  do
    group="$(echo $dataline | cut -d ':' -f 1)"
    propline="$(echo $dataline | cut -d ':' -f 2)"
    plugin="$(echo $propline | sed 's/\.[a-zA-Z0-9_-]*\ .*$//' )"
    attr="$(echo $propline | sed 's/^.*\.\([a-zA-Z0-9_-]*\)\ .*$/\1/' )"
    value="$(echo $propline | sed 's/^[^\ ]*\ //' )"

  done < $4/datafile
}

htd__munin_export()
{
  test -n "$1" || {
    test -n "$4" || set -- "" "$2" "$3" $DCKR_VOL/munin/db
    test -n "$3" || set -- "" "$2" g "$4" # or d
    test -n "$2" || set -- "" vs1/vs1-users-X-$2.rrd "$3" "$4"
    set -- "$4/$2-$3.rrd" "$2" "$3" "$4"
  }

  while read dataline
  do
    group="$(echo $dataline | cut -d ':' -f 1)"
    propline="$(echo $dataline | cut -d ':' -f 2)"
    plugin="$(echo $propline | sed 's/\.[a-zA-Z0-9_-]*\ .*$//' )"
    attr="$(echo $propline | sed 's/^.*\.\([a-zA-Z0-9_-]*\)\ .*$/\1/' )"
    value="$(echo $propline | sed 's/^[^\ ]*\ //' )"

    echo $dataline | grep -q 'title' && {
      echo "$group\t$plugin\t$attr\t$value"
    }
    echo $dataline | grep -qv '\.graph_' && {
      echo "$group\t$plugin\t$attr\t$value"
      #echo ls -la $4/$(echo $group | tr ';' '/')-$plugin-$(echo $attr | tr '.' '_' )-*.rrd
    }
  done < $4/datafile
# | column -tc 3 -s '\t'

  return

  # ds-name for munin is always 42?
  #"/srv/docker-local/munin-old-2015/db"

  for name in $4/*/*.rrd
  do
    basename "$name" .rrd
    continue
    rrdtool xport --json \
            DEF:out1=$1:42:AVERAGE \
            XPORT:out1:"42"
  done
}
