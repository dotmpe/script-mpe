#!/usr/bin/env bash


print_stats () # (env) ~
{
  echo "bt_rx_octets.value ${new_rx_octets:?}"
  echo "bt_tx_octets.value ${new_tx_octets:?}"
}

safe_ref () # ~ <File>
{
  echo ${session_number:?} ${session_rx_bytes:?} ${session_tx_bytes:?} > "${1:?}"
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

      read -r sessid last_rx last_tx

      init_ref "$1" || {
                echo "# Problem with last runs, stats file update still fails"
                return 1
            }

      test -z "$last_tx" && {
        # Don't report anything if something went wrong and last values are missing
        true

      } || {

        # Also won't report on first run after session (re)start
        test "$sessid" != "$session_number" \
            && echo "# New sesson: $session_number" \
            || {
                new_rx_octets=$(( session_rx_bytes - last_rx )) &&
                new_tx_octets=$(( session_tx_bytes - last_tx )) &&
                print_stats
            }
      }

      safe_ref "$1"
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

# Location for state files.
true "${PLUGSTATE:=${MUNIN_PLUGSTATE:-/tmp}}"

set -e

case ${1:-print} in

    ( autoconf ) echo "yes" ;;

    ( config ) cat <<EOM
graph_args --base 1000 --logarithmic
graph_category p2p
graph_info Transmission network traffic byte counters
graph_title BitTorrent Network Data
graph_vlabel bytes
bt_rx_octets.type GAUGE
bt_rx_octets.label Bytes read
bt_tx_octets.type GAUGE
bt_tx_octets.label Bytes send
EOM
        ;;

    ( print | update ) load && assert_helper &&
            update ${PLUGSTATE:?}/transmissionbt_xfer_octets.stats
        ;;

esac
