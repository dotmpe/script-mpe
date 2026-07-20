# .group.bash file, see User-Conf us-part for specification.
#
# Copyright 2008-2026 B. van Berkum <dev@dotmpe.com>
#
# Distribusertoolsed under terms of the MIT license.
usertools_bt_pre=User-Tools.BitTorrent
usertools_bt_var=(
)
usertools_bt_fun=(
  .clients
  .{Deluge,qBittorrent,Transmission}.torrentfiles
)
declare -gA \
usertools_bt_als=(
)
declare -gA \
usertools_bt_ssc=(
)
declare -gA \
usertools_bt_dep=(
  #pytp jq btcheck or btih_calc
  # XXX: see pip torrent-parser package for pytp exec script
)
declare -gA \
usertools_bt_hooks=(
  [declare]=\
': "${BTCLIENTS:=Transmission Deluge rTorrent qBittorrent}"
# XXX: this is actually just userdir and meta, nothing torrent specific
: "${BT_INFODIR:=${METADIR:?}/info}"
: "${BT_LOGDIR:=${METADIR:?}/log}"
: "${BT_TABS:=${METADIR:?}/tab}"
: "${BT_USER:=${METADIR:?}/user}"'

  [init]='
  bittorrent_info_vars_static="{info_{length,name,pcs,priv},magnet_{dn,btih}}"
  . <(echo "bittorrent_info_vars=( $bittorrent_info_vars_static )")
'
)

User-Tools.BitTorrent.clients () # ~ <Call args...>
{
  local btclient
  for btclient in ${BTCLIENTS:?}
  do ${usertools_bt_pre}${btclient}."${1:?}" "${@:2}" || return
  done
}

User-Tools.BitTorrent.Deluge.torrentfiles ()
{
  : "${DELUGEBT_UC_DIR:=$HOME/.config/deluge}"
  User-Script.OS.x.lookup-expand \
    DELUGEBT_UC_DIR "${1:?}" 'state/*.torrent'
}

User-Tools.BitTorrent.qBittorrent.torrentfiles ()
{
  : "${QBITTORRENT_UC_DIR:=$HOME/.local/share/qBittorrent}"
  User-Script.OS.x.lookup-expand \
    QBITTORRENT_UC_DIR "${1:?}" 'backup/*.torrent'
}

User-Tools.BitTorrent.Transmission.add ()
{
: input "${1:?$FUNCNAME ${*@Q}: Torrent file}"
: input "${2:?$FUNCNAME ${*@Q}: Save path}"
  transmission-remote \
      --add "$1" \
      --download-dir "$2" \
      ${3:---start}
}

User-Tools.BitTorrent.Transmission.torrentfiles ()
{
  : "${TRANSMISSIONBT_UC_DIR:=$HOME/.config/transmission}"
  User-Script.OS.x.lookup-expand \
    TRANSMISSIONBT_UC_DIR "${1:?}" 'torrents/*.torrent'
}

bittorrent_instances () # ~ ...
{
  bittorrent_clients instance
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


# Id: bt,user-tools         vim:set ft=bash sw=2 sts=2 et:
