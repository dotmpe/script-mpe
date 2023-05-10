#!/usr/bin/env bash

### Helpers to sort through Transmission downloads


transmission_lib__load ()
{
  : "${SHARE_DIR:=/srv/share-local}"
  : "${SHARE_DIRS:=$SHARE_DIR:/srv/share-1:/srv/share-2}"

  : "${TRANSMISSIONBT_TORRENTS_DIR:=$HOME/.config/transmission/torrents}"

  # ID and also local bind/address running rpc for transmission-remote
  : "${TRANSMISSIONBT_DEFAULT_CLIENT:=localhost:9091}"
}


transmission_instances ()
{
  std_pass "$(pidof -s transmission-gtk)" || return
  echo "transmission $TRANSMISSIONBT_DEFAULT_CLIENT $_ transmission-gtk"
}

transmission_client_remote () # [TRANSMISSIONBT_REMOTE] ~
{
  : "${TRANSMISSIONBT_REMOTE:-${TRANSMISSIONBT_DEFAULT_CLIENT:?}}"
  transmission-remote "$_" "$@"
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
  btplr=$(grep "^[0-9]\{5,\} $1 $2 " "${BT_PEER_LOG:?}" | tail -n 1) && {
    # If seen, get previously seen data percentage
    pct=$(echo "$btplr" | awk '{print $5}')
    # Append to peer log if peer share has increased, or if monitoring leeches
    test "$4" != "-" -o ${btp_leechlog:-0} -eq 0 && [[ ! $pct < $4 ]]
  } || {
    echo "$(date +'%s') $*" >>"${BT_PEER_LOG:?}"
  }
}

transmission_active () # ~
{
  test $# -gt 0 || set -- tab
  local lk=${lk:-}:transmission-active
  case "$1" in
    ( ids|nums )
          transmission_list ids active ;; #active tab | awk '{print $1}' ;;
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

# Basic scrapter utility for use with list-runner.
transmission_fix_item_cols () # (std) ~ # Remove whitespace from column values
{
  sed '
        s/\([0-9]\) \([kMGT]B\) /\1\2 /
        s/\([0-9]\) \(sec\|min\|hrs\|days\) /\1\2 /
        s/ Up & Down / Up-Down /
    '
}

# Ask transmission for download location of torrent
transmission_get_item () # ~ <Name>
{
  ti= transmission_info "$1" location:Location || return
  test -e "$location/$1" || return 100
  pp="$location/$1"

  #filetabs=$(transmission_client_remote -t "$num" -if | tail -n +3 | transmission_fix_item_cols)
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

  # Clear and check given argument
  test ${tid_chk:-1} -eq 0 || {
    num=; [[ $1 =~ ^[0-9]+\*?$ ]] && num=$1
    btih=; [[ $1 =~ ^[0-9a-f]{40}$ ]] && btih=$1
    name=; test -n "$num" -o -n "$btih" || name=$1
  }

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
  : "${ti:="$(transmission_client_remote -t "$1" -i)"}" || return
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
      # NOTE: Availability field is duplicated for missing-metadata downloads
      echo "$ti" | grep -m 1 "^ *$field:" | sed '
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
          shift; for i in "$TRANSMISSIONBT_TORRENTS_DIR/"*".${1:0:16}.torrent"
          do test -e "$i" && return || true; done; return 1
        ;;

    ( name )
          shift; for i in "$TRANSMISSIONBT_TORRENTS_DIR/$1."*".torrent"
          do test -e "$i" && return || true; done; return 1
        ;;

    ( * ) $LOG error "$lk" "No such action" "$1"; return 67 ;;
  esac
}

# Automatization scripts should probebly not run on items that Transmission has
# issues with, this transmission-list-item handler takes a subhandler that is
# only run if there are no issues for the current item.
# XXX: also checking wether the status was parsed correctly, but scripts should
# be using the validate function now when things go amiss.
transmission_item_check () # ~ [ <Handler <Arg...>> ]
{
  local lk="${lk:-}:check"
  true "${ti_c_quiet:=${quiet:-0}}"

  [[ $numid =~ \*$ ]] && {
    test $ti_c_quiet -eq 1 ||
      $LOG error "$lk" "Issues exist for" "$name"
    return 100 # XXX: continue with next if desired, but mark current as failed
  }

  # Check if read loop works correctly, we may have to catch some more
  # ETA or have-formats.
  case "$status" in
    ( Idle | Downloading | Seeding | Uploading | Stopped | Up-Down | Queued | Finished ) ;;
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

# List run handler: list file(s) in share at client backend
transmission_item_files () # ~
{
  filetabs=$(transmission_client_remote -t "$num" -if | tail -n +3)
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
    test "$1" = "--" || "$@"
  }
}

# List run handler with operations: pause shares under conditions
transmission_item_pause () # ~
{
  ti_c_quiet=1 transmission_item_percentage -- || return

  test "$State" = "Stopped" && {
      return
  }
  test "$pct" = "100" \
      -a "$status" = "Idle" \
      -a ${ratio/.*} -ge 2 && {

    transmission_client_remote -t "$btih" -S
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

  # Keep fishing for missing metadata
  test -z "$pct" && return

  #test "$have" != "None" && return

  peers=$(grep " $Hash " "${BT_PEER_LOG:?}") && {
    echo "to-pause: $num $name $Hash $Availability $have"
    echo "$peers"
  } || true
  # || {
    #echo pause: $num $Hash $Availability
    transmission_client_remote -t "$btih" -S
    $LOG notice "" "Paused" "$btih:$name:$Availability"
  #}
}

transmission_item_peers () # ~ [<transmission_item_peers_logupdate>]
{
  ti_c_quiet=1 transmission_item_percentage -- || return

  # NOTE: -pi is an alias for -ip and --info-peers
  peers=$(transmission_client_remote -t "$num" -pi | tail -n +2)
  test -n "$peers" || return 100

  test ${quiet:-0} -eq 1 || {
    test $status = Idle &&
        echo "$numid. $name ($status, $pct of $avail)" ||
        echo "$numid. $name ($status, $pct of $avail, $up/$down)"
    echo "$peers" | sed 's/^/  /'
  }

  # Finish peers handler: run peerlog update or defer to inner handler if args given
  test $# -eq 0 && {
    set -- transmission_item_peers_logupdate
  }
  test "${1:-}" = "--" || "$@"
}

transmission_item_peers_logupdate ()
{
  # Updated bt net peer/hash log
  echo "$peers" | transmission_fix_item_cols |
      tee -a "${METADIR:?}/tabs/btpeers.list" |
      while read -r ipaddr mode pct up down client_agent
      do
        btp_seedlog=1 btpeers_logupdate "$ipaddr" "$btih" "${mode:--}" "$pct" "$client_agent"
      done

  #test $ti_pl_quiet -eq 1 ||
  #    $LOG notice "$lk" "$num OK" "$name; $status"
}

# Scraping output we miss some raw data. This selects some and tries to use
# proper variable names.
transmission_item_percentage () # ~
{
  # Skip shares with issues and abort on unknown status
  transmission_item_check || return

  ti= transmission_info "$num" btih:Hash status:State \
    avail:Availability size_tot:Total.size

  # Progress (and other variables) can be nan for numbers, and None for other
  # value types, if no metadata (torrent-file) is yet available.
  # In these cases set progress to empty.

  #test "$done_pct" = "-nan%" \
  #    && { done_pct=n/a; progress=; } \
  #    || progress=${done_pct//%/}

  test "$avail" = "-nan%" -o "$avail" = "None" && avail=n/a

  test $# -eq 0 && {
    printf 'ID: %s\nName: %s\nHash: %s\nState: %s\nAvailability: %s\n'\
'Percentage: %s\nTotal size: %s\n' \
          "$numid" "$name" "$btih" "$status" "$avail" "$pct" "$size_tot"
  } || {
    test "${1:?}" = "--" || "$@"
  }
}

transmission_item_available () # ~
{
  #ti_c_quiet=1 transmission_item_percentage -- || return
  #test "$avail" = n/a || return 0
  transmission_list_item
}

transmission_list_item () # ~
{
  echo "$numid ${pct:-n/a} $have $eta $up $down $ratio $status $name"
}

transmission_item_trackers () # ~ [<Inner-handler>]
{
  trackers_raw=$(transmission_client_remote -t "$num" -it)
  tcnt=$(echo "$trackers_raw" | grep -c 'Tracker [0-9]')
  trackers=$(echo "$trackers_raw" | grep -oP '^ *Tracker\ [1-9][0-9]*: \K.*')
  # echo "$trackers_raw" | grep 'an error' | sed 's/Got an error //' || true

  test ${quiet:-0} -eq 1 || {
    echo "$numid. $name (Trackers: $tcnt)"
    echo "$trackers" | sed 's/^/  /'
  }

  test $# -eq 0 && return
  test "${1:?}" = "--" || "$@"
}

transmission_item_validate () # ~
{
  local fail failed
  [[ $numid =~ ^[0-9]{1,}\*?$ ]] || fail=Num\ ID
  test -z "${num:-}" || {
    [[ $num =~ ^[0-9]{1,}$ ]] || fail=ID; }
  [[ $pct =~ ^[0-9]{,}$ ]] || fail=Percentage
  [[ $have =~ ^(None|([0-9]{1,}\.[0-9]{1,}[kMGT]B))$ ]] || fail=Have
  [[ $eta =~ ^(Unknown|Done|([0-9]{1,}[minhrsday]{1,4}))$ ]] || fail=Eta
  [[ $up =~ ^[0-9]{1,}\.[0-9]{1,}$ ]] || fail=Up
  [[ $down =~ ^[0-9]{1,}\.[0-9]{1,}$ ]] || fail=Down
  [[ $ratio =~ ^(None|([0-9]{1,}\.[0-9]{1,}))$ ]] || fail=Ratio
  [[ $status =~ ^(Uploading|Downloading|Up-Down|Seeding|Stopped|Finished|Queued|Idle)$ ]] \
      || fail=Status
  test -z "${btih:-}" || {
    [[ $btih =~ ^[0-9a-f]{40}$ ]] || fail=Bt\ info-hash; }
  test -z "${fail-}" && return

  ctx="id:$numid pct:$pct have:$have eta:$eta up:$up down:$down ratio:$ratio ih:${btih:-} status:$status n:$name"
  $LOG warn ":item-validate" "$fail failed" "${ctx//%/%%}"

  test ${ti_v_ff:-0} -eq 1 && return 1
  return 100
}

# Container for actions that wrap `transmission-remote -l`, for more complex
# commands and batch operations see usage of transmission-list-run.
transmission_list () # ~ <Action ...> # Filter/process clients list output
{
  test $# -gt 0 || set -- tab
  local lk=${lk:-}:transmission-list
  case "$1" in

    ( a|active )
          transmission_client_remote -l | grep -e 'Uploading' -e 'Downloading' -e 'Seeding' ;;
    ( S|not-stopped )
          transmission_client_remote -l | grep -v '\(None\|[1-9][0-9]*\) * Stopped ' ;;
    ( idle )
          transmission_client_remote -l | grep 'Idle' ;;
    ( e|errors|issues )
          transmission_client_remote -l | grep -E '^ * [0-9]+\* ' ;;
    ( popular )
          transmission_client_remote -l |
            grep -E '  *[0-9]+\.[0-9]+  *[0-9]+\.[0-9]+  *[1-9][0-9]*\.[0-9] ' |
            transmission_fix_item_cols | sort -k7n
        ;;
    ( s|stopped|paused )
          transmission_client_remote -l | grep '\(None\|[0-9][0-9]*\) * Stopped ' ;;

    ( fix-cols )
          shift; transmission_list "$@" | transmission_fix_item_cols ;;
    ( I|ids )
          shift; transmission_list "$@" | awk '{print $1}' ;;
    ( i|items ) # ~ (<Handler>) <Id-Spec...> # Shortcut to run given handler on selected IDs
          shift; local handler=${1:-lognote}; shift
          transmission_list_run fix-cols items-by-nums "$@" -- \
              transmission_item_$handler ;;
    ( items-by-nums ) # ~ [<List-Arg...> -- ] <Id...>
          local listarg listargc
          shift; transmission_listarg "$@" && shift $listargc
          test $# -gt 0 || {
            $LOG error "$lk" "Item ID arguments expected"
            return 64
          }
          transmission_list $listarg | grep "^ *\<$( grep_or "$@" )\> "
        ;;
    ( key|keys|cols ) # ~ [ <List-Arg...> -- ] <Var:Field...>
          test "$1" = "cols" && ti_row=1 || {
            test "$1" = "key" -o "$1" = "col" && ti_keymap=0 || ti_keymap=1;
          }
          local listarg listargc
          shift; transmission_listarg "$@" && shift $listargc
          test $# -gt 0 || {
            $LOG error "$lk" "Key var names or map arguments expected"
            return 64
          }
          transmission_list_run $listarg -- transmission_item_keys "$@"
        ;;
    ( summary )
          transmission_list_summary ;
          $LOG notice "$lk:summary" \
"Sharing $sum in $cnt shares, current transfer rates: $down down, $up up"
        ;;
    ( tab|all )
          transmission_client_remote -l ;;
    ( u|unknown )
          transmission_list xtab | grep Unknown | grep -E '^ *[0-9]+\*?  *n/a' ;;
    ( v|validate )
          transmission_list_run transmission_item_validate ;;
    ( xtab )
          transmission_list fix-cols tab ;;

    ( * ) $LOG error "$lk" "No such action" "$1"; return 67 ;;
  esac
}

transmission_listarg ()
{
  listargc=$#
  local more=false
  while fnmatch "* -- *" " $* "
  do more=true
    argv_q=0 argv_more "$@" && shift $more_argc ; listarg="$more_argv"
    unset more_arg{v,c}
    shift
    true "${listarg:="fix-cols tab"}"
  done
  true "${listarg:="fix-cols tab"}"
  listargc=$(( listargc - $# ))
  $more
}

# A simple and compact basis to write handlers to parse transmission-remote -l
# output. This only handles arguments to the reader and runner functions. See
# tranmission-listarg, and the base runner/parser routine is in
# transmission-list-runner. Handler name is a full function name, default is
# transmission-item-check. See also other examples 'transmission_item_*' here.
#
transmission_list_run () # ~ [ <List-Arg...> -- ] <Handler <Args...>>
{
  local listarg listargc
  transmission_listarg "$@" && shift $listargc

  true "${tl_runner:=transmission_list_runner}"
  test $# -gt 0 || set -- transmission_item_check

  lk=${lk:-}:list-run transmission_list $listarg | "$tl_runner" "$@"
}

# Basic reader/parser line-handler for transmission_list xtab-formatted outputs.
transmission_list_runner () # [quiet] ~ <Handler <Args...>>
{
  test $# -gt 0 || set -- transmission_item_check
  local numid pct have eta up down ratio status name
  local r ret num lk="${lk:-}:list-runner:${1//transmission_item_}"

  while read -r numid pct have eta up down ratio status name
  do
    test "$numid" = ID && continue
    test "$numid" != "Sum:" && {

      num=${numid//\*/}
      pct=$(echo "$pct" | tr -d 'n/a%')

      test ${tlr_quiet:-${quiet:-0}} -eq 1 || {
        test $(expr $num % ${tl_li:-100}) -ne 0 -o $num -eq 0 ||
          $LOG notice "$lk" "$num items read..."
      }

      # Defer to handler, and handle return
      "$@" || { r=$?
        test $r -eq 100 && {
          ret=1
          continue
        }
        test ${tlr_quiet:-${quiet:-0}} -eq 1 ||
          $LOG "error" "$lk" "Failed on $num" "E$r:$name"
        return $r
      }

    } || {
      test ${tlr_quiet:-${quiet:-0}} -eq 1 ||
        $LOG notice "$lk" "All items read, summary:" \
            "size:$pct items:$num xfer:: up:$have down:$eta"
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
  test $# -gt 1 || set -- num
  test "$1" = num -o "$1" = "hash" || return 67
  test -n "$name" || return 63
  tid_chk=0 transmission_id "$1" "$name"
}

transmission_num_env () # ~ (hash|name)
{
  test $# -gt 1 || set -- hash
  test "$1" = hash -o "$1" = "name" || return 67
  test -n "$num" || return 63
  tid_chk=0 transmission_id "$1" "$num"
}

# XXX:
transmission_remote () # ~ <Argv...>
{
  local remote sessionid
  remote="${TRANSMISSIONBT_REMOTE:-${REMOTE:-${TRANSMISSIONBT_DEFAULT_CLIENT:?}}}"
  sessionid=$(REMOTE=$remote transmission_session_id)
  test -n "$sessionid"
  #curl -X HEAD -H X-Transmission-Session-Id:\ $session_id $remote/transmission/rpc/
  #test "$rpcres" = 'localhost:9091/transmission/rpc/ responded: "success"'
}

transmission_session_id ()
{
  local remote
  remote="${TRANSMISSIONBT_REMOTE:-${REMOTE:-${TRANSMISSIONBT_DEFAULT_CLIENT:?}}}"
  curl -qs --head "$remote"/transmission/rpc/ |
      grep -Po 'X-Transmission-Session-Id: \K.*'
}

transmission_share ()
{
  #test $# -gt 0 || set -- info
  local lk=${lk:-}:transmission-share
  case "${1:?}" in

    ( find ) # ~ <Id-Spec> <Path>
          transmission_client_remote -t "${2:?}" --find "${3:?}" ;;
    ( move ) # ~ <Id-Spec> <Path>
          transmission_client_remote -t "${2:?}" --move "${3:?}" ;;
    ( s|start ) # ~ <Id-Spec>
          transmission_client_remote -t "${2:?}" --start ;;
    ( S|stop ) # ~ <Id-Spec>
          transmission_client_remote -t "${2:?}" --stop ;;

    ( * ) $LOG error "$lk" "No such action" "$1"; return 67 ;;
  esac
}

#
