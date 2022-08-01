#!/usr/bin/env bash

# Max torrent share ratio, mean, total cumulative and per-session share ratios
# XXX: might want share ratios per active torrent group, may be


report ()
{
  echo "max_shareratio.value $max_shareratio"
  echo "active_max_shareratio.value $active_max_shareratio"
  echo "active_avg_shareratio.value $active_avg_shareratio"
  echo "seeding_max_shareratio.value $seeding_max_shareratio"
  echo "seeding_avg_shareratio.value $seeding_avg_shareratio"
  echo "session_shareratio.value $session_shareratio"
  echo "total_shareratio.value $total_shareratio"
}

update ()
{
  set -- \
      ${PLUGSTATE:?}/transmissionbt_shareratios.cache

  transmission-remote -l | transmission_fix_item_cols >"$1" || return

  max_shareratio=$(list_all "$1" | max_shareratio)
  active_max_shareratio=$(list_active "$1" | max_shareratio)
  active_avg_shareratio=$(list_active "$1" | avg_shareratio)
  seeding_max_shareratio=$(list_seeding "$1" | max_shareratio)
  seeding_avg_shareratio=$(list_seeding "$1" | avg_shareratio)

  eval "$(FMT=sh ${helper_py:?} shareratios)"

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
graph_title BitTorrent Share Ratios
graph_vlabel ratio
max_shareratio.type GAUGE
max_shareratio.label Max. share ratio
active_max_shareratio.type GAUGE
active_max_shareratio.label Max. active share ratio
active_avg_shareratio.type GAUGE
active_avg_shareratio.label Avg. active share ratio
seeding_max_shareratio.type GAUGE
seeding_max_shareratio.label Max. seeding share ratio
seeding_avg_shareratio.type GAUGE
seeding_avg_shareratio.label Avg. seeding share ratio
session_shareratio.type GAUGE
session_shareratio.label Session share ratio
total_shareratio.type GAUGE
total_shareratio.label Cumulative share ratio
EOM
        ;;

    ( print | update )
            update
        ;;

esac

#
