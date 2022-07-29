#!/usr/bin/env bash

### Helpers to sort through transmission downloads

transmission_lib_load ()
{
  : "${SHARE_DIR:=/srv/share-local/}"
  : "${SHARE_DIRS:=$SHARE_DIR:/srv/share-1:/srv/share-2}"

  : "${TORRENTS_DIR:=$HOME/.config/transmission/torrents}"
}


# Log peers/torrents when seen on bittorrent net. By default only log for hashes
# on our wishlist, corrupt or missing lists. I.e. not the current seeds.
btpeers_logupdate () # ~ <Ip-Addr> <Info-Hash> <Mode> <Percentage> <Client-Agent>
{
  # Normally only monitor only select set of hashes that we want. Set to
  # monitor for every seed we see.
  test ${btp_seedlog:-0} -eq 1 || {
    torrent_updatelog_find "$2" wishlist missing corrupt || return 0
  }

  # If 0.0 is reported, check if Transmission knowns about availabiity
  test "$4" = "0.0" && {
    ti= transmission_info "$2" "Availability"
    test "$Availability" != "-nan%" || {
      set -- "$1" "$2" "$3" "-" "$5"
      test ${btp_leechlog:-0} -eq 0 && return
    }
  }

  # Check if IP/hash combo was ever seen for duration of log
  btplr=$(grep "^[0-9]\{5,\} $1 $2 " "$BT_PEER_LOG" | tail -n 1) && {
    # If seen, get previously seen data percentage
    pct=$(echo "$btplr" | awk '{print $5}')
    # Append to peer log if peer share has increased, or if monitoring leeches
    test "$4" != "-" -o ${btp_leechlog:-0} -eq 0 && [[ ! $pct < $4 ]]
  } || {
    echo "$(date +'%s') $*" >>"$BT_PEER_LOG"
  }
}

transmission_active () # ~
{
  test $# -gt 0 || set -- tab
  case "$1" in
    ( tab ) transmission_list active ;;
    ( xtab ) transmission_active tab | transmission_fix_item_cols ;;
    ( id ) transmission_active xtab | awk '{print $1}' ;;
    ( btih ) for numid in $(transmission_active id )
            do transmission_get_hash "$numid"; done
          ;;
    ( * ) return 67 ;;
  esac
}

transmission_fix_item_cols () # ~
{
  sed '
        s/\([0-9]\) \([kMG]B\) /\1\2 /
        s/\([0-9]\) \(min\|hrs\|days\) /\1\2 /
        s/ Up & Down / Up-Down /
    '
}

# This should be must faster than looking for the share name ourself on the fs
transmission_get_item () # ~ <Name>
{
  transmission_get_num "$@" || return
  num=${numid/\*/}
  location=$(transmission-remote -t "$num" -i | grep Location: | awk '{print $2}')
  test -e "$location/$1" || return 1
  pp="$location/$1"

  #filetabs=$(transmission-remote -t "$num" -if | tail -n +3 | transmission_fix_item_cols)
  #echo "num=$numid
  #echo "$1"
  #echo "$location"
  #echo "$filetabs" | sed 's/^/  /'
}

transmission_get_hash () # ~ <Num-Or-Name>
{
  ti= transmission_info "$1" Hash && echo "$Hash"
}

transmission_get_num () # ~ <Name>
{
  test $# -eq 1 -a -n "${1:-}" || return
  local n_re
  n_re=$(match_grep "$1")
  numid=$(transmission-remote -l | grep " $n_re$" | awk '{print $1}')
  test -n "$numid"
}

transmission_info () # ~ <Id-Spec> <Key...>
{
  : "${ti:="$(transmission-remote -t "$1" -i)"}"
  shift
  ti_sh="$(
      while test $# -gt 0
      do
          echo "$ti" | grep "^ *$1:" | sed '
          s/^ *[^:]*: \(.*\)$/'"${1// /_}"'="\1"/
            '
          shift
      done )"
  eval "$ti_sh"
}

transmission_is_item () # ~ <Name>
{
  test -e "$(echo "$TORRENTS_DIR/$1."*".torrent")"
}

# Return (info-)name for numeric Id
transmission_item_by_num () # ~ <Num>
{
  transmission_list xitem "$1" | awk '{print $9}'
}

# Just checking wether the row was parsed correctly.
transmission_item_check () # ~
{
  [[ $numid =~ \*$ ]] && {
    test ${ti_c_quiet:-0} -eq 1 ||
      $LOG error "shared-list" "Issues exist for" "$name"
    return 100
  }
  num=${numid}

  # Check if read loop works correctly, we may have to catch some more
  # ETA or have-formats.
  case "$status" in
    ( Idle | Downloading | Seeding | Uploading | Stopped | Up-Down | Queued ) ;;
    ( * ) $LOG error "shared-list" "Unknown status '$status'" "$name";
      #echo "pct='$pct' have='$have' eta='$eta' up='$up' down='$down'"
      return 100 ;; esac
}

transmission_item_files () # ~
{
  #transmission_item_check || return
  num=${numid/\*/}
  filetabs=$(transmission-remote -t "$num" -if | tail -n +3)
  echo "$name"
  echo "$filetabs" | sed 's/^/  /'
}

transmission_item_info () # ~
{
  num=${numid/\*/}
  transmission-remote -t "$num" -i
}

transmission_item_pause () # ~
{
  ti_c_quiet=1 transmission_item_percentage || return
  test "$State" = "Stopped" && return

  test "$pct" = n/a -o "$pct" = "0%" || return 0

  #test "$have" != "None" && return
  echo "to-pause: $num $Hash $Availability $have"

  grep -q " $Hash " "$BT_PEER_LOG" && {
    true
  } || {
    #echo pause: $num $Hash $Availability
    transmission-remote -t "$btih" -S
    $LOG notice "" "Paused" "$btih:$name:$Availability"
  }
}

transmission_item_percentage () # ~
{
  # Skip shares with issues or unknown status
  transmission_item_check || return

  ti= transmission_info "$num" State Hash "Percent Done" "Availability"
  btih=$Hash
  test $Percent_Done = "-nan%" && Percent_Done=n/a
  test $Availability = "-nan%" && Availability=n/a
  true
}

transmission_item_peers () # ~
{
  transmission_item_percentage || return

  # NOTE: -pi is an alias for -ip and --info-peers
  peers=$(transmission-remote -t "$num" -pi | tail -n +2)
  test -n "$peers" || return 100

  test ${quiet:-0} -eq 1 || {
    test $status = Idle &&
        echo "$numid. $name ($status, $Percent_Done of $Availability)" ||
        echo "$numid. $name ($status, $Percent_Done of $Availability, $up/$down)"
    echo "$peers" | sed 's/^/  /'
  }

  # Updated bt net peer/hash log
  echo "$peers" | transmission_fix_item_cols |
      while read -r ipaddr mode pct up down client_agent
      do
        btp_seedlog=1 btpeers_logupdate "$ipaddr" "$btih" "${mode:--}" "$pct" "$client_agent"
      done
}

# TODO: Move to complete, partial folders.
transmission_item_sort () # ~
{
  transmission_item_check || return
  #num=${numid/\*/}
  #transmission_share_move "$num" "pub/complete/$grpd"
}

transmission_item_trackers () # ~
{
  #transmission_item_check || return
  num=${numid/\*/}
  trackers=$(transmission-remote -t "$num" -it)
  tcnt=$(echo "$trackers" | grep 'Tracker [0-9]' | count_lines)
  echo "$numid. $name ($tcnt)"
  echo "$trackers" | grep 'an error' | sed 's/Got an error //' || true
}

transmission_list () # ~
{
  test $# -gt 0 || set -- tab
  case "$1" in

    ( active ) transmission-remote -l | grep -e 'Uploading' -e 'Downloading' -e 'Seeding' ;;
    ( stopped|paused ) transmission-remote -l | grep -e 'Stopped' ;;
    ( idle ) transmission-remote -l | grep -e 'Idle' ;;

    ( item ) shift; transmission-remote -l | grep '^ * '$1'\*\? ' ;;
    ( tab ) transmission-remote -l ;;
    ( summary ) transmission_list_summary ;
          lognote ":transmission-list:summary" \
"Sharing $sum in $cnt shares, current transfer rates: $down down, $up up"
        ;;

    ( fix-cols ) shift; transmission_list "$@" | transmission_fix_item_cols ;;
    ( xtab ) transmission_list tab | transmission_fix_item_cols ;;
    ( xitem ) shift; transmission_list item "$1" | transmission_fix_item_cols ;;

    ( unknown ) transmission_list xtab | grep Unknown | grep -E '^ *[0-9]+\*?  *n/a' ;;

    ( * ) return 67 ;;
  esac
}

transmission_list_parse () # ~ <Row-Handler> [<Index-Spec>...]
{
  local tlh="$1" is=${2:-}
  shift

  transmission_list fix-cols tab | {
    local numid pct have eta up down ratio status name
    local r num
    while read -r numid pct have eta up down ratio status name
    do
      test "$numid" = ID && continue
      test "$numid" != "Sum:" && {
        pct=$(echo "$pct" | tr -d '%')
        cnt=${numid//\*/}
        test ${quiet:-0} -eq 1 || {
          test $(expr $cnt % ${tl_li:-100}) -ne 0 -o $cnt -eq 0 ||
            lognote "" "$cnt rows read..."
        }

        test -z "$is" || {
          # Skip if index given
          test "$numid" = "$1*" -o "$numid" = "$1" && {
            shift
          } || {
            continue
          }
        }

        # Defer to handler
        "$tlh" || { r=$?
          test $r -eq 100 && continue
          return $r
        }

        test -z "$is" || {
          test $# -gt 0 || break
        }

      } || {
        test ${quiet:-0} -eq 1 ||
            echo "Shared $pct GB over $cnt shares,"\
" current transfer rates: $eta down, $have up"
        break
      }
    done
  }
}

# Get numer of shares, shared size, and current up/down rates from last two
# transmission-list lines.
transmission_list_summary () # ~ # Get share summary variables
{
  local tlf
  tlf=$( transmission_list xtab | tail -n 2 )
  cnt=$(echo "$tlf" | head -n 1 | awk '{print $1}')
  tls=$(echo "$tlf" | tail -n 1)
  sum=$(echo "$tls" | awk '{print $2}')
  up=$(echo "$tls" | awk '{print $3}')
  down=$(echo "$tls" | awk '{print $4}')
}

transmission_share_find () # ~ <Num> <Path>
{
  transmission-remote -t "$1" --find "$2"
}

transmission_share_move () # ~ <Num> <Path>
{
  transmission-remote -t "$1" --move "$2"
}

transmission_statistics ()
{
  transmission_list summary
  transmission-remote -st
  echo
}

#
