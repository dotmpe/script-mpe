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

#
