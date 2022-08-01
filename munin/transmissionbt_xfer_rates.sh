#!/usr/bin/env bash


print_stats () # (env) ~
{
  echo "bt_rx_rate.value ${new_rx_rate:?}"
  echo "bt_tx_rate.value ${new_tx_rate:?}"
}

safe_ref () # ~ <File>
{
  echo ${session_number:?} ${session_seconds:?} ${session_rx_bytes:?} ${session_tx_bytes:?} > "${1:?}"
}

init_ref () # ~ <File>
{
  #shellcheck disable=2209
  eval "$(FMT=sh ${helper_py:?} transfer_stats)" && safe_ref "${1:?}"
}


update ()
{
  test ! -e "${1:?}" && {
    # Can't do stats on first run
    init_ref "$1" || return

  } || {

    head -n1 "$1" | {

      read -r sessid last_rt last_rx last_tx

      test -z "$last_tx" && {
        # Don't report anything if something went wrong and last values are missing
        init_ref "$1" || return

      } || {

        #shellcheck disable=2209
        eval "$(FMT=sh ${helper_py:?} transfer_rates_since \
            ${last_rt:?} ${last_rx:?} ${last_tx:?})" || return
        echo "# Delta: $delta_seconds seconds"

        # Also won't report on first run after session (re)start
        test "$sessid" = "$session_number" \
            && print_stats \
            || echo "# New sesson: $session_number"

        safe_ref "$1"
      }
    }
  }
}


# Munin shell lib, mainly for use with thresholds.
# true "${MUNIN_LIBDIR:=/usr/share/munin}/plugins/plugin.sh"

# Location for state files.
# true "${MUNIN_PLUGSTATE:=/var/run/munin}"
true "${PLUGSTATE:=${MUNIN_PLUGSTATE:=/tmp}}"

true "${helper_py:=/srv/home-local/bin/transmission.py}"

set -e

case ${1:-print} in

    ( autoconf ) echo "yes" ;;

    ( config ) cat <<EOM
graph_args --logarithmic
graph_category p2p
graph_title BitTorrent Network Rates
graph_vlabel bytes/sec
bt_rx_rate.type GAUGE
bt_rx_rate.label Bytes/sec read
bt_tx_rate.type GAUGE
bt_tx_rate.label Bytes/sec send
EOM
        ;;

    ( print | update )
            update ${PLUGSTATE:?}/transmissionbt_xfer_rates.stats
        ;;

esac

#
