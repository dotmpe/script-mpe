#!/usr/bin/env bash

### Helpers to sort through transmission downloads

transmission_lib_load ()
{
  : "${SHARE_DIR:=/srv/share-local}"
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
      # Don't know if share has metadata, Transmission doesn't know about it
      test ${btp_leechlog:-0} -eq 0 && return
      set -- "$1" "$2" "$3" "-" "$5"
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
  local lk=${lk:-}:transmission-active
  case "$1" in
    ( ids )
          transmission_active tab | awk '{print $1}' ;;
    ( key|keys|cols ) # ~ <Var:Field...>
          local act="$1"; shift; set -- "$1" fix-cols active -- "$@"
          transmission_list "$@" ;;
    ( tab )
          transmission_list active ;;
    ( xtab )
          transmission_list fix-cols active ;;

    ( * ) $LOG error "$lk" "No such action" "$1"; return 67 ;;
  esac
}

transmission_fix_item_cols ()
{
  sed '
        s/\([0-9]\) \([kMGT]B\) /\1\2 /
        s/\([0-9]\) \(min\|hrs\|days\) /\1\2 /
        s/ Up & Down / Up-Down /
    '
}

# This should be must faster than looking for the share name ourself on the fs
transmission_get_item () # ~ <Name>
{
  ti= transmission_info "$1" location:Location || return
  test -e "$location/$1" || return 1
  pp="$location/$1"

  #filetabs=$(transmission-remote -t "$num" -if | tail -n +3 | transmission_fix_item_cols)
  #echo "num=$numid
  #echo "$1"
  #echo "$location"
  #echo "$filetabs" | sed 's/^/  /'
}

# Helper for user input that sorts out what argument is given, and what to
# fetch. If any. If we know what type of input we have, use transmission-*-env.
transmission_id () # ~ (id|hash|name) <Hash-or-Num-or-Name>
{
  test $# -gt 0 || return 64
  test $# -gt 1 || set -- id "$1"
  local lk=${lk:-}:id

  num=; [[ $1 =~ ^[0-9]+\*?$ ]] && num=$1
  btih=; [[ $1 =~ ^[0-9a-f]{40}$ ]] && btih=$1
  name=; test -n "$num" -o -n "$btih" || name=$1

  local ti=
  case "$1" in
    ( info-hash|btih|hash ) # ~ <Id-Spec> # Ensure BTIH env for torrent ID
          test -n "$btih" || transmission_info "$1" btih:Hash
        ;;
    ( id|num ) # ~ <Id-Spec> # Ensure numeric ID env for torrent ID
          test -n "$num" || transmission_info "$1" num:ID
        ;;
    ( info-name|name ) # ~ <Id-Spec> # Ensure Info-Name env for torrent ID
          test -n "$name" || transmission_info "$1" name:Name
        ;;
    ( - ) ;;

    ( * ) $LOG error "$lk" "No such action" "$1"; return 67 ;;
  esac
}

transmission_info () # ~ <Id-Spec> <Key...> # Parse info output and set vars
{
  : "${ti:="$(transmission-remote -t "$1" -i)"}" || return
  shift
  ti_sh="$(
    while test $# -gt 0
    do
      fnmatch "*:*" "$1" && {
        field=${1/*:}
        var=${1/:*}
      } || {
        field=$1 var=${1// /_}
      }
      echo "$ti" | grep "^ *$field:" | sed '
          s/^ *[^:]*: \(.*\)$/'"$var"'="\1"/
        '
      shift
    done )"
  eval "$ti_sh"
}

# To check wether a name or hash is a transmission share, this is far quicker
# than calling transmission-remote. But there are a few cases it fails for
# names.
transmission_is_item () # ~ [name|hash] <Info-Name-or-Hash>
{
  test $# -gt 0 || return 64
  test $# -gt 1 || set -- name "$1"
  local lk=${lk:-}:is-item
  case "$1" in
    ( hash )
          shift; for i in "$TORRENTS_DIR/"*".${1:0:16}.torrent"
          do test -e "$i" && return || true; done; return 1
        ;;

    ( name )
          shift; for i in "$TORRENTS_DIR/$1."*".torrent"
          do test -e "$i" && return || true; done; return 1
        ;;

    ( * ) $LOG error "$lk" "No such action" "$1"; return 67 ;;
  esac
}

transmission_item_cb ()
{
  local argvar="$2" arg
  arg=${!argvar}
  "$1" "$arg" || {
    $LOG error "$lk:cb:$num" "Callback '$1' failed" "${arg//%/%%}"
    return 100
  }
}

# Just checking wether the row was parsed correctly.
transmission_item_check () # ~ [ <Handler <Arg...>> ]
{
  local lk="${lk:-}:check"
  true "${ti_c_quiet:=${quiet:-0}}"

  [[ $numid =~ \*$ ]] && {
    test $ti_c_quiet -eq 1 ||
      $LOG error "$lk" "Issues exist for" "$name"
    return 100
  }

  # Check if read loop works correctly, we may have to catch some more
  # ETA or have-formats.
  case "$status" in
    ( Idle | Downloading | Seeding | Uploading | Stopped | Up-Down | Queued ) ;;
    ( * )
      test $ti_c_quiet -eq 1 ||
        $LOG error "$lk" "Unknown status '$status'" "$name";
      return 1 ;; esac

  # Finish check. Or defer to inner handler if args given
  test $# -eq 0 && {
    test $ti_c_quiet -eq 1 ||
      $LOG notice "$lk" "$num OK" "$name; $status"
  } || "$@"
}

transmission_item_files () # ~
{
  filetabs=$(transmission-remote -t "$num" -if | tail -n +3)
  printf '%s:\n%s\n' "$name" "$(echo "$filetabs" | sed 's/^/  /')"
}

# Util. item wrapper to fetch and map properties from transmission-info.
# Without inner handler this prints the values retrieved, prefixed with ID and
# Name fields, or single values if only one map given (and ti_keymap!=1).
# To print all values in a single row, without keys, set ti_row=1. In this case
# no mappings, only field parts are needed. See transmission-info.
transmission_item_keys () # ~ <Keys...> [ -- <Handler <Argv...>> ]
{
  local keymap
  argv_q=0 argv_more "$@" || return; shift $more_argc ; keymap="$more_argv"
  unset more_arg{v,c}

  test -n "$keymap" || {
    $LOG error "$lk:item-keys" "Expected key-map"
    return 1
  }
  local ti
  transmission_info "$num" $keymap || return

  test $# -eq 0 && {
    set -- $keymap
    test ${ti_row:-0} -ne 1 && {
      test ${ti_keymap:-0} -eq 1 -o $# -gt 1 &&
          printf 'num: %s\nname: %s\n' "$numid" "$name" || true
    } || {
      printf '%s ' "$numid"
    }
    for km in $keymap
    do
      fnmatch "*:*" "$km" && var=${km/:*} || var=${km// /_}
      test ${ti_row:-0} -ne 1 -a \( ${ti_keymap:-0} -eq 1 -o $# -gt 1 \) &&
            echo "$var: ${!var}" ||
            echo "${!var}"
    done | { test ${ti_row:-0} -eq 1 && { lines_to_words; echo; } || cat; }

    return $?
  } || {
    test "$1" = "-" || "$@"
  }
}

transmission_item_pause () # ~
{
  ti_c_quiet=1 transmission_item_percentage - || return

  test "$State" = "Stopped" && {
      return
  }
  test "$pct" = "100" \
      -a "$status" = "Idle" \
      -a ${ratio/.*} -ge 2 && {

    transmission-remote -t "$btih" -S
    $LOG notice "" "Paused" "$btih:$name"

    #echo "to-pause: $num $Hash $ratio $pct/$Availability $have $status $up/$down"
  }
  #test "$down" = "0.0" \
  #-a "$up" = "0.0" \

  #echo "$num $name $up $down"
  return 0
  test "$Availability" = "100%" -o "$status" != "Idle" || {

    #:$Availability"
    return
  }

  test "$pct" = n/a -o "$pct" = "0%" || return 0

  #test "$have" != "None" && return

  peers=$(grep " $Hash " "$BT_PEER_LOG") && {
    echo "to-pause: $num $name $Hash $Availability $have"
    echo "$peers"
  } || true
  # || {
    #echo pause: $num $Hash $Availability
    transmission-remote -t "$btih" -S
    $LOG notice "" "Paused" "$btih:$name:$Availability"
  #}
}

transmission_item_peers () # ~
{
  ti_c_quiet=1 transmission_item_percentage - || return

  # NOTE: -pi is an alias for -ip and --info-peers
  peers=$(transmission-remote -t "$num" -pi | tail -n +2)
  test -n "$peers" || return 100

  test ${quiet:-0} -eq 1 || {
    test $status = Idle &&
        echo "$numid. $name ($status, $done_pct of $avail)" ||
        echo "$numid. $name ($status, $done_pct of $avail, $up/$down)"
    echo "$peers" | sed 's/^/  /'
  }

  # Updated bt net peer/hash log
  echo "$peers" | transmission_fix_item_cols |
      while read -r ipaddr mode pct up down client_agent
      do
        btp_seedlog=1 btpeers_logupdate "$ipaddr" "$btih" "${mode:--}" "$pct" "$client_agent"
      done
}

transmission_item_percentage () # ~
{
  # Skip shares with issues and abort on unknown status
  transmission_item_check || return

  ti= transmission_info "$num" btih:Hash status:State \
    avail:Availability done_pct:Percent.Done size_tot:Total.size

  test "$done_pct" = "-nan%" && done_pct=n/a
  test "$avail" = "-nan%" && avail=n/a

  test $# -eq 0 && {
    printf 'ID: %s\nName: %s\nHash: %s\nState: %s\nAvailability: %s\n'\
'Percentage: %s\nTotal size: %s\n' \
          "$numid" "$name" "$btih" "$status" "$avail" "$done_pct" "$size_tot"
  } || {
    test "${1:-}" = "-" || "$@"
  }
}

transmission_item_trackers () # ~
{
  trackers=$(transmission-remote -t "$num" -it)
  tcnt=$(echo "$trackers" | grep 'Tracker [0-9]' | count_lines)
  echo "$numid. $name ($tcnt)"
  echo "$trackers" | grep 'an error' | sed 's/Got an error //' || true
}

transmission_list () # ~
{
  test $# -gt 0 || set -- tab
  local lk=${lk:-}:transmission-list
  case "$1" in

    ( active )
          transmission-remote -l | grep -e 'Uploading' -e 'Downloading' -e 'Seeding' ;;
    ( stopped|paused )
          transmission-remote -l | grep '\(None\|[0-9][0-9]*\) * Stopped ' ;;
    ( not-stopped )
          transmission-remote -l | grep -v '\(None\|[0-9][0-9]*\) * Stopped ' ;;
    ( idle )
          transmission-remote -l | grep -e 'Idle' ;;

    ( popular )
          transmission-remote -l |
            grep -E '  *[0-9]+\.[0-9]+  *[0-9]+\.[0-9]+  *[1-9][0-9]*\.[0-9] ' |
            transmission_fix_item_cols | sort -k7n
        ;;

    ( item )
          shift; transmission-remote -l | grep '^ * '$1'\*\? ' ;;
    ( tab )
          transmission-remote -l ;;
    ( summary )
          transmission_list_summary ;
          $LOG notice "$lk:summary" \
"Sharing $sum in $cnt shares, current transfer rates: $down down, $up up"
        ;;

    ( fix-cols )
          shift; transmission_list "$@" | transmission_fix_item_cols ;;
    ( unknown )
          transmission_list xtab | grep Unknown | grep -E '^ *[0-9]+\*?  *n/a' ;;
    ( xtab )
          transmission_list fix-cols tab ;;
    ( xitem )
          shift; transmission_list fix-cols item "$1" ;;

    ( key|keys|cols ) # ~ [ <List-Arg...> -- ] <Var:Field...>
          test "$1" = "cols" && ti_row=1 || {
            test "$1" = "key" -o "$1" = "col" && ti_keymap=0 || ti_keymap=1;
          }
          shift
          local listarg
          ! fnmatch "* -- *" " $* " || {
            argv_q=0 argv_more "$@" && shift $more_argc ; listarg="$more_argv"
            unset more_arg{v,c}
          }
          true "${listarg:="fix-cols tab"}"
          transmission_list_run $listarg -- transmission_item_keys "$@"
        ;;

    ( * ) $LOG error "$lk" "No such action" "$1"; return 67 ;;
  esac
}

# A simple and compact basis to write handlers to parse transmission-remote -l
# output.
# This only handles arguments, the base parser is transmission_list_runner.
#
transmission_list_run () # ~ [ <List-Arg...> -- ] <Handler <Args...>>
{
  local listarg lk=${lk:-}:list-run
  ! fnmatch "* -- *" " $* " || {
    argv_q=0 argv_more "$@" && shift $more_argc ; listarg="$more_argv"
    unset more_arg{v,c}
  }
  true "${listarg:="fix-cols tab"}"

  true "${tl_runner:=transmission_list_runner}"
  test $# -gt 0 || set -- transmission_item_check

  transmission_list $listarg | "$tl_runner" "$@"
}

# Basic reader for transmission_list xtab-formatted outputs.
transmission_list_runner () # [quiet] ~ <Handler <Args...>>
{
  test $# -gt 0 || set -- transmission_item_check
  local numid pct have eta up down ratio status name
  local r ret num lk="${lk:-}:list-runner"
  while read -r numid pct have eta up down ratio status name
  do
    test "$numid" = ID && continue
    test "$numid" != "Sum:" && {
      pct=$(echo "$pct" | tr -d '%')
      num=${numid//\*/}
      test ${quiet:-0} -eq 1 || {
        test $(expr $num % ${tl_li:-100}) -ne 0 -o $num -eq 0 ||
          $LOG notice "$lk" "$num rows read..."
      }

      # Defer to handler, and handle return
      "$@" || { r=$?
        test $r -eq 100 && {
          ret=1
          continue
        }
        test ${quiet:-0} -eq 1 ||
          $LOG "error" "$lk" "Failed on $num" "$name"
        return $r
      }

    } || {
      test ${quiet:-0} -eq 1 ||
        $LOG notice "$lk" "Summary" \
            "size:$pct items:$num xfer:$have up/$eta down"
      break
    }
  done
  return ${ret:-0}
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

transmission_name_env () # ~ (num|hash)
{
  test -n "$name" || return 63
  test $# -gt 1 || set -- hash
  local lk=${lk:-}:name-env
  case "$1" in
    ( id|num|numid ) # ~ <Id-Spec> # Ensure Id env for torrent name
          transmission_info "$name" num:ID
          test -n "$num" || return
        ;;
    ( info-hash|btih|hash ) # ~ <Id-Spec> # Ensure BTIH env for torrent name
          transmission_info "$name" btih:Hash
          test -n "$btih" || return
        ;;

    ( * ) $LOG error "$lk" "No such action" "$1"; return 67 ;;
  esac
}

transmission_num_env () # ~ (hash|name)
{
  test -n "$num" || return 63
  test $# -gt 1 || set -- hash
  local lk=${lk:-}:num-env
  case "$1" in
    ( info-hash|btih|hash ) # ~ <Id-Spec> # Ensure BTIH env for torrent ID
          transmission_info "$num" btih:Hash
          test -n "$btih" || return
        ;;
    ( info-name|name ) # ~ <Id-Spec> # Ensure Info-Name env for torrent ID
          transmission_info "$num" name:Name
          test -n "$name" || return
        ;;

    ( * ) $LOG error "$lk" "No such action" "$1"; return 67 ;;
  esac
}

transmission_share_find () # ~ <Num> <Path>
{
  transmission-remote -t "$1" --find "$2"
}

transmission_share_move () # ~ <Num> <Path>
{
  transmission-remote -t "$1" --move "$2"
}

#
