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
  eval "$(FMT=sh ${helper_py:?} --transfer-stats)" && safe_ref "${1:?}"
}


update ()
{
  test ! -e "${1:?}" && {
    # Can't do stats on first run
    init_ref "$1" || return
    echo "# First run only created stats file, re-run to get delta's"

  } || {

    head -n1 "$1" | {

      read -r sessid last_rt last_rx last_tx

      test -z "$last_tx" && {
        # Don't report anything if something went wrong and last values are missing
        init_ref "$1" && echo "# Problem with last run, re-created stats file" \
            || {
                echo "# Problem with last runs, still can't created stats file"
                return 1
            }

      } || {

        #shellcheck disable=2209
        eval "$(FMT=sh ${helper_py:?} --transfer-rates-since \
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

load ()
{
  true "${US_BIN:=/srv/home-local/bin}"
  test -e "$MUNIN_LIBDIR/plugins/transmissionbt-munin.lib.sh" &&
      . "$MUNIN_LIBDIR/plugins/transmissionbt-munin.lib.sh" ||
      . "$US_BIN/transmissionbt-munin.lib.sh"
}

true "${MUNIN_LIBDIR:=/usr/share/munin}"

# Munin shell lib, mainly for use with thresholds.
# . "${MUNIN_LIBDIR:=/usr/share/munin}/plugins/plugin.sh"

# Location for state files.
# true "${MUNIN_PLUGSTATE:=/var/run/munin}"
true "${PLUGSTATE:=${MUNIN_PLUGSTATE:-/tmp}}"

set -e

case ${1:-print} in

    ( autoconf ) echo "yes" ;;

    ( config ) cat <<EOM
# With peaks in data above the million I think logarithmic is more readable
graph_args --base 1000 --logarithmic -l 0.7 -r
graph_category p2p
graph_info Transmission network data use
# XXX: This has no effect on vertical axis labels with log type, but changes
# legend
#graph_scale no
#graph_scale yes
graph_title BitTorrent Network Rates
graph_vlabel bytes/sec
bt_rx_rate.type GAUGE
bt_rx_rate.label Bytes/sec read
bt_tx_rate.type GAUGE
bt_tx_rate.label Bytes/sec send
EOM
        ;;

    ( print | update ) load && assert_helper &&
            update ${PLUGSTATE:?}/transmissionbt_xfer_rates.stats
        ;;

esac

#
