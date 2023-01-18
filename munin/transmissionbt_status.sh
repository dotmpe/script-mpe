#!/usr/bin/env bash

# Peer and active torrent count monitoring plugin for Munin
#
# Don't need total I think.
# XXX: Do want count of stalled torrents if possible.
# TODO: And torrents which received corrupt data. And incomplete ones and
# missing ones.


report ()
{
  echo "active_torrents.value $active_torrents"
  echo "queued_torrents.value $queued_torrents"
  echo "idle_torrents.value $idle_torrents"
  echo "seeding_torrents.value $seeding_torrents"
  echo "connections.value $connections"
  echo "uploading_torrents.value $uploading_torrents"
  echo "downloading_torrents.value $downloading_torrents"
  echo "error_torrents.value $error_torrents"
  echo "paused_torrents.value $paused_torrents"
  echo "finished_torrents.value $finished_torrents"
  echo "total_torrents.value $total_torrents"
  echo "peers.value $peers"
  echo "missing_torrents.value $missing_torrents"
  #echo "incomplete.value $incomplete"
}

update ()
{
  set -- \
      ${PLUGSTATE:?}/transmissionbt_list.cache

  transmission-remote -l >"$1" || return

  downloading_torrents=$(grep_f=c list_downloading "$1" || true )
  uploading_torrents=$(grep_f=c list_uploading "$1" || true )
  updown_torrents=$(grep_f=c list_updown "$1" || true)
  seeding_torrents=$(grep_f=c list_seeding "$1" || true )
  queued_torrents=$(grep -c ' Queued ' "$1" || true )
  idle_torrents=$(grep -c ' Idle ' "$1" || true )
  error_torrents=$(grep_f=c list_issues "$1" || true)
  paused_torrents=$(grep -c ' Stopped ' "$1")
  finished_torrents=$(grep -c ' Finished ' "$1")
  missing_torrents=$(grep -c '^ *[0-9]* * n/a ' "$1")
  #incomplete_torrents=$()

  #up_torrents=$(grep -c ' Uploading ' "$1" || true )
  # Total = finished_torrents + downloading_torrents + queued_torrents +
  #   paused_torrents + up_torrents + idle_torrents + seeding_torrents
  total_torrents=$(list_all "$1" | count)

  active_torrents=$(( updown_torrents + seeding_torrents ))

  set -- "$1" "$1.peers"
  test ! -s "$2" || rm "$2"
  for active_id in $(list_active "$1" | awk '{print $1}')
  do id=${active_id//\*/}
    transmission-remote -t "$id" -pi >>"$2"
  done

  connections=$(count "$2")
  peers=$(awk '!a[$1]++' < "$2" | count)

  report
}

load ()
{
  true "${US_BIN:=/srv/home-local/bin}"
  test -e "$MUNIN_LIBDIR/plugins/transmissionbt-munin.lib.sh" &&
      . "$MUNIN_LIBDIR/plugins/transmissionbt-munin.lib.sh" ||
      . "$US_BIN/transmissionbt-munin.lib.sh"
}

true "${MUNIN_LIBDIR:=/usr/share/munin}"

# Location for state files.
# true "${MUNIN_PLUGSTATE:=/var/run/munin}"
true "${PLUGSTATE:=${MUNIN_PLUGSTATE:-/tmp}}"

set -euo pipefail

case ${1:-print} in

    ( autoconf ) echo "yes" ;;

    ( config ) cat <<EOM
# The amounts are far apart, but not enough yet. With sub-1k values, the
# 0.001-1.0 order takes about a third of the graph in logarithmic scale;
# --rigid prevents plots below 1e+00. Now we can only read 1 or above but can
# still read 0 values in the legend.
graph_args --base 1000 --logarithmic -l 0.8 -r
graph_category p2p
graph_info Transmission states over time
graph_printf %7.0lf
graph_scale no
graph_title BitTorrent Status
graph_vlabel counts
active_torrents.type GAUGE
active_torrents.label Active total
active_torrents.info Sum of all Uploading, Downloading and Seeding torrents
queued_torrents.type GAUGE
queued_torrents.label Queue size
idle_torrents.type GAUGE
idle_torrents.label Idled
idle_torrents.info By deault inactivity for 30 minutes marks a torrent Idle
seeding_torrents.type GAUGE
seeding_torrents.label Seeding
connections.type GAUGE
connections.label Peer connections
connections.info The sum of connected peers for all torrents
uploading_torrents.type GAUGE
uploading_torrents.label Uploading
downloading_torrents.type GAUGE
downloading_torrents.label Downloading
error_torrents.type GAUGE
error_torrents.label Exceptions
error_torrents.info Misconfigured torrents
paused_torrents.type GAUGE
paused_torrents.label Paused
finished_torrents.type GAUGE
finished_torrents.label Finished
total_torrents.type GAUGE
total_torrents.label Total
peers.type GAUGE
peers.label Peers connected
peers.info The number of unique peers
#stalled_torrents.type GAUGE
#stalled_torrents.label Stalled
#stalled_torrents.info XXX: not sure, maybe a bit set once Idle time expires?
missing_torrents.type GAUGE
missing_torrents.label No metadata
missing_torrents.info Unknown file size or name
#incomplete_torrents.type GAUGE
#incomplete_torrents.label Incomplete data
#incomplete_torrents.info Available data is less than 100%
EOM
        ;;

    ( print | update ) load && assert_helper && assert_running || exit $?
        update ;;

esac

#
