#!/bin/sh

htd_man_1__emby='

  emby (un)favorite ID
    Add/remove favorite item.
  emby (un)like | remove-like ID
    Add, change or remove "Likes" setting.

  emby studio [ID]
    List all or get one studio item.
  emby year(s) [YEAR]
    List all or show one year item.

  emby logs
    List available logs
  emby plugins
    List installed plugins
  emby scheduled [ID]
    List all or get one scheduled tasks item.

  item-roots
  items

  TODO: items-sub
  TODO: items-by-id
  TODO: item-images
    Tabulate images
'
htd__embyapi()
{
  lib_load curl meta emby
  emby_api_init
  test $# -gt 0 || set -- default
  subcmd_prefs=${base}_emby__\ emby_api__ try_subcmd_prefixes "$@"
}
htd__emby() { htd__embyapi "$@"; }


htd__exif()
{
  exiftool -DateTimeOriginal \
      -ImageDescription -ImageSize \
      -Rating -RatingPercent \
      -ImageID -ImageUniqueID -ImageIDNumber \
      -Copyright -CopyrightStatus \
      -Make -Model -MakeAndModel -Software -DateTime \
      -UserComment  \
    "$@"
}


# validate torrent
htd__ck_torrent()
{
  test -s "$1" || error "Not existent torrent arg 1: $1" 1
  test -f "$1" || error "Not a torrent file arg 1: $1" 1
  test -z "$2" -o -d "$2" || error "Missing dir arg" 1
  htwd=$PWD
  dir=$2
  test "$dir" != "." && pushd $2 > /dev/null
  test "${dir: -1:1}" = "/" && dir="${dir:0: -1}"
  log "In $dir, verify $1"

  #echo testing btshowmetainfo
  #btshowmetainfo $1

  node $PREFIX/bin/btinfo.js "$1" > $sys_tmp/htd-ck-torrent.sh
  . $sys_tmpd/htd-ck-torrent.sh
  echo BTIH:$infoHash

  torrent-verify.py "$1" | while read line
  do
    test -e "${line}" && {
      echo $htwd/$dir/${line} ok
    }
  done
  test "$dir" != "." && popd > /dev/null
}


# xxx find corrupt files: .mp3
htd__mp3_validate()
{
  eval "find . $find_ignores -o -name "*.mp3" -a \( -type f -o -type l \) -print" \
  | while read p
  do
    SZ=$(filesize "$p")
    test -s "$p" || {
      error "Empty file $p"
      continue
    }
    mp3val "$p"
  done
}

htd__read_torrents ()
{
  while test $# -gt 0
  do
      htd__read_torrent "${1:?}" || return
  done
}

htd__read_torrent ()
{
  bittorrent_read "${1:?}"
  echo "Torrent-File: $1"
  echo "Display-Name: $dn"
  echo "Info-Hash: $btih"

  echo "$tjs" | jq '.info.files'
}

#
