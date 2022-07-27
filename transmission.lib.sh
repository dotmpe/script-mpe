#!/usr/bin/env bash

### Helpers to sort through transmission downloads

transmission_lib_load ()
{
  : ${SHARE_DIR:=/srv/share-local/}
  : ${SHARE_DIRS:=$SHARE_DIR:/srv/share-1:/srv/share-2}

  : ${TORRENTS_DIR:=$HOME/.config/transmission/torrents}
}


# Just checking wether the row was parsed correctly.
transmission_item_check () # ~
{
  [[ $numid =~ \*$ ]] && {
    $LOG error "shared-list" "Issues exist for" "$name"
    return 100
  }
  num=${numid}

  # Check if read loop works correctly, we may have to catch some more
  # ETA or have-formats.
  case "$status" in
    ( Idle | Downloading | Seeding | Uploading | Stopped | Up-Down ) ;;
    ( * ) $LOG error "shared-list" "Unknown status '$status'" "$name";
      #echo "pct='$pct' have='$have' eta='$eta' up='$up' down='$down'"
      return 100 ;; esac
}

transmission_list () # ~ <Row-Handler>
{
  transmission-remote -l | sed '
        s/\([0-9]\) \([kMG]B\) /\1\2 /
        s/\([0-9]\) \(min\|hrs\|days\) /\1\2 /
        s/ Up & Down / Up-Down /
      ' |
  {
    local numid pct have eta up down ratio status name
    local r num
    while read -r numid pct have eta up down ratio status name
    do
      test "$numid" = ID && continue
      test "$numid" != "Sum:" && {

        pct=$(echo "$pct" | tr -d '%')

        # Defer to handler
        "$1" || { r=$?
          test $r -eq 100 && continue
          return $r
        }
      } || {
        echo "Shared $pct GB over $num shares,"\
" current transfer rates: $eta down, $have up"
        break
      }
    done
  }
}

transmission_move () # ~ <Torrent-Spec> <Path>
{
  false
}

#
