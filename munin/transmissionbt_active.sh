#!/usr/bin/env bash

# Peer and active torrent count monitoring with Munin
#
# Don't need total I think.
# XXX: Do want count of stalled torrents if possible.
# TODO: And torrents which received corrupt data.


report ()
{
  echo "active_torrents.value $active_torrents"
  echo "queued_torrents.value $queued_torrents"
  echo "idle_torrents.value $idle_torrents"
  echo "seeding_torrents.value $seeding_torrents"
  echo "peers.value $peers"
  echo "uploading_torrents.value $uploading_torrents"
  echo "downloading_torrents.value $downloading_torrents"
  echo "error_torrents.value $error_torrents"
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

  active_torrents=$(( updown_torrents + seeding_torrents ))

  peers=0
  for active_id in $(list_active "$1" | awk '{print $1}')
  do id=${active_id//\*/}
    peers=$(( peers + $(transmission-remote -t "$id" -pi | wc -l | cut -d ' ' -f 1) - 1))
  done

  report
}

# Location for state files.
# true "${MUNIN_PLUGSTATE:=/var/run/munin}"
true "${PLUGSTATE:=${MUNIN_PLUGSTATE:=/tmp}}"

true "${helper_py:=/srv/home-local/bin/transmission.py}"

#. /usr/share/munin/plugins/transmissionbt.sh
. /srv/home-local/bin/munin/transmissionbt.sh

set -e

case ${1:-print} in

    ( autoconf ) echo "yes" ;;

    ( config ) cat <<EOM
graph_args --logarithmic
graph_category p2p
graph_title BitTorrent Active Shares
graph_vlabel counts
active_torrents.type GAUGE
active_torrents.label Active total
queued_torrents.type GAUGE
queued_torrents.label Queue size
idle_torrents.type GAUGE
idle_torrents.label Idled
seeding_torrents.type GAUGE
seeding_torrents.label Seeding
peers.type GAUGE
peers.label Connected peers
uploading_torrents.type GAUGE
uploading_torrents.label Uploading
downloading_torrents.type GAUGE
downloading_torrents.label Downloading
error_torrents.type GAUGE
error_torrents.label Exceptions
EOM
        ;;

    ( print | update )
            update
        ;;

esac

#
