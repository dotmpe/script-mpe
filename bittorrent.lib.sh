bittorrent_lib__load ()
{
  : "${BTCLIENTS:=transmission}"
  test -z "${BTCLIENTS:-}" && return
  lib_require $BTCLIENTS || return

  : "${BT_INFODIR:=${METADIR:?}/info}"
  : "${BT_LOGDIR:=${METADIR:?}/log}"
  : "${BT_PEER_LOG:=$BT_LOGDIR/torrents-net.log}"
}

bittorent_lib__init ()
{
  test -d "$BT_LOGDIR" || mkdir -vp "$BT_LOGDIR" >&2
  test -d "$BT_INFODIR" || mkdir -vp "$BT_INFODIR" >&2
}


bittorrent_instances ()
{
  local btclient
  for btclient in $BTCLIENTS
  do
    "$btclient"_instances
  done
}

# FIXME: client-id is not properly tracked yet, but one instance works fine
bittorrent_list_run () # ~ <List-run-arg...> # Go over every open torrent
{
  test -z "${CLIENT_ID:-}" && {
    local btclient
    for btclient in $BTCLIENTS
    do
      "$btclient"_list_run "$@"
    done
  } || {
    lk=bittorrent:$CLIENT/${CLIENT_PID:-} \
    REMOTE=$CLIENT_ID "${CLIENT:?}"_list_run "$@"
  }
}

# Parse Magnet URI reference with btih key. Pure bash solution to decode, split
# and read values into variables. This captures the like-named field values as
# variables ``magnetref-{dn,btih,tr}`` where the last one is an indexed array.
btmagnet_parse () # ~ <Magnet-uriref> # Decode and set $magnetref_{dn,btih,tr}
{
  magnetref_dn=
  magnetref_btih=
  declare -ga magnetref_tr=()

  : "${1:?}"
  # Strip scheme:?
  : "${1:8}"
  # URL encoded spaces
  : "${_//+/ }"
  # Replace other URL encoded chars with something echo -e/printf understands
  # as an escape sequence.
  : "${_//%/\\x}"

  magnetref_decoded="$_"
  local query_field
  while read -r query_field
  do
    case "$query_field" in
      ( "dn="* )
          magnetref_dn=${query_field:3}
        ;;
      ( "tr="* )
          magnetref_tr+=( ${query_field:3} )
        ;;
      ( "xt=urn:btih:"* )
          magnetref_btih=${query_field:12}
        ;;
      ( * ) echo "Unknown field: '$query_field'" >&2
        return 2 ;;
    esac
  done <<< "$(printf "${magnetref_decoded//&/\\n}")"
}
