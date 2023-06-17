bittorrent_lib__load ()
{
  : "${BTCLIENTS:=transmission}"
  test -z "${BTCLIENTS:-}" && return
  lib_require meta $BTCLIENTS || return

  : "${BT_INFODIR:=${METADIR:?}/info}"
  : "${BT_LOGDIR:=${METADIR:?}/log}"
  : "${BTLOG_PEERS:=$BT_LOGDIR/torrents-net.log}"
}

bittorent_lib__init ()
{
  test -z "${BTCLIENTS:-}" && return
  test -d "$BT_LOGDIR" || mkdir -vp "$BT_LOGDIR" >&2
  test -d "$BT_INFODIR" || mkdir -vp "$BT_INFODIR" >&2
}

bittorent_lib__install ()
{
  command -v pytp >/dev/null 2>&1 &&
  command -v jq >/dev/null 2>&1
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
bittorrent_magnet_parse () # ~ <Magnet-uriref> # Decode and set $magnetref_{dn,btih,tr}
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

# Read initial parts from torrent file (the magnet info-hash and display-name)
# Uses pytp and jq to retrieve data.
bittorrent_magnet_read () # ~ <Torrent-file> # Read torrent-magnet parts: infohash and displayname
{
  tjs= mijs= btih= dn=
  tjs="$(pytp "$1")" &&
  # Parse-out and keep magnet-info JSON since if info/parts etc present JSON
  # can be much larger than just magnet-info.
  mijs="$(echo "$tjs" | jq -r '.["magnet-info"]')" &&
  btih="$(echo "$mijs" | jq -r '.info_hash')" &&
  dn="$(echo "$mijs" | jq -r '.["display-name"]')"
}

# Use pytp to parse torrent file to JSON, and get pieces of data from it.
# Return 12 if magnet info but no share metadata is present.
bittorrent_read () # ~ <Torrent-File> # Read .torrent magnet info and metadata if available
{
  in= length= parts=
  tbn="$(basename "$1")" &&
  bittorrent_magnet_read "$1" || return

  test "$btih" != null || {
    test ${quiet:-0} -eq 1 ||
      $LOG warn "torrent-read" "No BTIH in torrent file" "$tbn"
    return 11
  }

  test "$( echo "$tjs" | jq '.info' )" != "null" || {
    test ${quiet:-0} -eq 1 ||
      $LOG warn "torrent-read" "No metadata for BTIH" "$btih:$tbn"
    return 12
  }

  # Read torrent metadata: file or folder name
  in="$(echo "$tjs" | jq -r '.info.name')"

  # If we find a length, we have a single-part torrent. Otherwise we have a
  # folder.
  length=$(echo "$tjs" | jq '.["info"].length')
  test "${length:-null}" != "null" && parts= || {
    length=
    parts=$(echo "$tjs" | jq '.["info"].files | length')
  }
}
