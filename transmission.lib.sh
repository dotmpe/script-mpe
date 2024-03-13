#!/usr/bin/env bash

### Helpers to sort through Transmission downloads


transmission_lib__load ()
{
  : "${SHARE_DIR:=/srv/share-local}"
  : "${SHARE_DIRS:=$SHARE_DIR:/srv/share-1:/srv/share-2}"

  : "${TRANSMISSIONBT_UC_DIR:=$HOME/.config/transmission}"
  : "${TRANSMISSIONBT_BLOCKLIST_DIR:=${TRANSMISSIONBT_UC_DIR:?}/blocklist}"
  : "${TRANSMISSIONBT_TORRENTS_DIR:=${TRANSMISSIONBT_UC_DIR:?}/torrents}"
  : "${TRANSMISSIONBT_SETTINGS_JSON:=${TRANSMISSIONBT_UC_DIR:?}/settings.json}"
  : "${TRANSMISSIONBT_STATS_JSON:=${TRANSMISSIONBT_UC_DIR:?}/stats.json}"

  # ID and also local bind/address running rpc for transmission-remote
  : "${TRANSMISSIONBT_DEFAULT_CLIENT:=localhost:9091}"

  : "${TARGET_SEED_RATIO:=2}"

  : "${_E_next:=196}" # failed, but can proceeed with batch/loop
}

# Manages just one default instance
transmission_instances ()
{
  std_pass "$(pidof -s transmission-gtk)" || return
  echo "transmission $TRANSMISSIONBT_DEFAULT_CLIENT $_ transmission-gtk"
}

# Wrapper to call currently selected instance
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
    ti="" transmission_torrent_info "$2" "Availability"
    test "$Availability" != "-nan%" || {
      # Don't know if share has metadata, Transmission doesn't know about it
      test ${btp_leechlog:-0} -eq 0 && return
      set -- "$1" "$2" "$3" "-" "$5"
    }
  }

  # Check if IP/hash combo was ever seen for duration of log
  btplr=$(grep "^[0-9]\{5,\} $1 $2 " "${BTLOG_PEERS:?}" | tail -n 1) && {
    # If seen, get previously seen data percentage
    pct=$(echo "$btplr" | awk '{print $5}')
    # Append to peer log if peer share has increased, or if monitoring leeches
    test "$4" != "-" -o ${btp_leechlog:-0} -eq 0 && [[ ! $pct < $4 ]]
  } || {
    echo "$(date +'%s') $*" >>"${BTLOG_PEERS:?}"
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
          #local act="$1"; shift; set -- "$1" fix-cols active -- "$@"
          transmission_list keys fix-cols active -- "${@:2}" ;;
    ( tab )
          transmission_list active ;;
    ( xtab )
          transmission_list fix-cols active ;;

    ( * ) $LOG error "$lk" "No such action" "$1" 67
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
  ti= transmission_torrent_info "$1" location:Location || return
  test -e "$location/$1" || return ${_E_next:?}
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
          test -n "$btih" || transmission_torrent_info "$1" btih:Hash
        ;;
    ( id|num ) # ~ <Id-Spec> # Ensure numeric ID env for torrent ID
          test -n "$num" || transmission_torrent_info "$1" num:ID
        ;;
    ( info-name|name ) # ~ <Id-Spec> # Ensure Info-Name env for torrent ID
          test -n "$name" || transmission_torrent_info "$1" name:Name
        ;;
    ( - ) ;;

    ( * ) $LOG error "$lk" "No such action" "$1"; return 67 ;;
  esac
}

transmission_info ()
{
  case "${1:?}" in
    ( stats ) transmission_client_remote -st
      ;;
    ( session-info ) transmission_client_remote -si
      ;;
    ( up|down|up-down|updown )
        transmission_client_remote -l | tail -n 1 | {
          read -r _ _ _ up down
          case "$1" in
            ( up ) echo "$up";;
            ( down ) echo "$down";;
            ( up-down|updown ) echo "$up $down";;
          esac
        }
      ;;
  esac
}

transmission_torrent_info () # ~ <Id-Spec> <Key...> # Parse info output and set vars
{
  if_ok "${ti:="$(transmission_client_remote -t "$1" -i)"}" || return
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
      echo "${ti//\'/\\\'}" | grep -m 1 "^ *$field:" | sed '
          s/^ *[^:]*: \(.*\)$/'"$var"'='"'"'\1'"'"'/
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
  true "${ti_c_quiet:=${quiet:-0}}"

  [[ $numid =~ \*$ ]] && {
    test $ti_c_quiet -eq 1 ||
      $LOG error "$lk" "Issues exist for" "$name"
    return ${_E_next:?}
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

# Reset variables that are not read directly as part of while-read-loop.
transmission_item_clearenv ()
{
  tjs= mijs= btih= dn= tbn= in= length= parts=
  #tf
  avail= avail_pct= size_tot= progress=
  test $# -eq 0 || "$@"
}

transmission_item_echo () # ~
{
  local out="$numid. $name
    Status:$status Progress:${pct:-n/a}"
  test -z "${eta:-}" || out="$out ETA:$eta"
  test -z "${have:-}" || out="$out Have:$have"
  test -z "${avail:-}" || out="$out Available:$avail"
  test -z "${ratio:-}" || out="$out Ratio:$ratio"
  test -z "${size_tot:-}" || out="$out Total-size:$size_tot"
  test -z "$up" -a -z "$down" || out="$out Speed:$up/$down"
  echo "$out"
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
  args_q=0 args_more "$@" || return; shift $more_argc ; keymap="$more_args"
  unset more_arg{v,c}

  test -n "$keymap" || {
    $LOG error "$lk:item-keys" "Expected key-map"
    return 1
  }
  local ti
  transmission_torrent_info "$num" $keymap || return

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

# List-run handler: Count shares using various selectors
transmission_item_count () # ~ [<Modes...>] [-- <Inner-handler>]
{
  transmission_item_clearenv
  transmission_item_share_select "$@" || return
  while test $# -gt 0
  do
    ti_sel=count share_select "$@" || {
      test ${_E_next:?} -eq $? && return ||
          test ${_E_break:?} -eq $_ && break ||
              return $_
    }
    shift
    test $# -eq 0 && return
  done
  #transmission_item_echo
  sa_ti_lctx_progress
  $LOG notice ":$numid" "Counted share" "$lctx"
  counted=$(( counted + 1 ))
  sa_next_seq
  test $# -eq 0 || "$@"
}
transmission_item_count_pre ()
{
  counted=0
}
transmission_item_count_post ()
{
  $LOG crit : "Counted $counted shares" "$*"
}

# List-run handler: Pause shares using various modes.
transmission_item_pause () # ~ [<Modes...>] [-- <Inner-handler>]
{
  ! ${skip_issues:-true} || {
    ${has_issue:-false} && return
  }
  case "$status" in ( Stopped | Finished | Queued ) return 0 ;; esac
  transmission_item_clearenv
  transmission_item_share_select "$@" || return

  # Inclusive selection modes break on matching, exclusive modes return from
  # handler upon not-matching. FIXME: add prefix to trigger behaviour
  # The first modes are inclusive select: when triggered the immeadeatly skip to
  # the share-start action, else the next mode is checked.
  # Some other modes are excluse, when not applicable they stop the pause handler
  # immeadeatly and the runner continues check the next share.
  while test $# -gt 0
  do
    ti_sel=pause share_select "$@" || {
      test ${_E_next:?} -eq $? && return ||
          test ${_E_break:?} -eq $_ && break ||
              return $_
    }
    shift
    test $# -eq 0 && return
  done

  sa_ti_lctx_progress
  transmission_remote_do -t "$num" -S &&
      $LOG notice ":$numid" "Paused" "$lctx" ||
      $LOG error ":$numid" "Error pausing" "E$?:$lctx" $?
  paused=$(( paused + 1 ))
  sa_next_seq
  test $# -eq 0 || "$@"
}
transmission_item_pause_pre ()
{
  paused=0
}
transmission_item_pause_post ()
{
  $LOG crit : "Paused $paused shares" "$*"
}

# Collect lists of currently connected peers per share
transmission_item_peers () # ~ [<transmission_item_peers_logupdate>]
{
  ti_c_quiet=1 transmission_item_share_info -- || return

  # NOTE: -pi is an alias for -ip and --info-peers
  peers=$(transmission_client_remote -t "$num" -pi | tail -n +2)
  test -n "$peers" || return ${_E_next:?}

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
  ti="" transmission_torrent_info "$num" btih:Hash || return

  # Updated bt net peer/hash log
  echo "$peers" | transmission_fix_item_cols |
      tee -a "${METADIR:?}/tab/btpeers.list" |
      while read -r ipaddr mode pct up down client_agent
      do
        btp_seedlog=1 btpeers_logupdate "$ipaddr" "$btih" "${mode:--}" "$pct" "$client_agent"
      done

  #test $ti_pl_quiet -eq 1 ||
  #    $LOG notice "$lk" "$num OK" "$name; $status"
}

transmission_item_select () # ~
{
  transmission_item_clearenv
  transmission_item_share_select "$@" || return
  while test $# -gt 0
  do
    ti_sel=pause share_select "$@" || {
      test ${_E_next:?} -eq $? && return ||
          test ${_E_break:?} -eq $_ && break ||
              return $_
    }
    shift
    test $# -eq 0 && return
  done
  transmission_item_echo
  selected=$(( selected + 1 ))
  sa_next_seq
  test $# -eq 0 || "$@"
}
transmission_item_select_pre ()
{
  selected=0
}
transmission_item_select_post ()
{
  $LOG crit : "Selected $selected shares" "$*"
}

# FIXME: (tl-li) ~ [<Inner-handlers> ] -- <Query> [ -- <...> ]
transmission_item_share_select () # (tl-li) ~ <Query...>
{
  local fields
  fields=$(share_select_info "$@") || return
  transmission_info_fields $fields
}

transmission_info_fields ()
{
  local fields="$*"
  set -- $(for field in $fields
      do test -z "${!field:-}" || continue # Skip already defined vars
        case "$field" in
        ( num|numid|pct|have|eta|up|down|ratio|status|name ) ;;
        ( btih ) echo $field:Hash ;;
        ( progress ) echo $field:Percent.Done ;;
        ( avail ) echo $field:Availability ;;
        ( size_tot ) echo $field:Total.size ;;
        ( * ) $LOG error "$lk:transmission-info-fields" "Unknown field" "$field" 1 ;;
        esac
      done)
  test $# -eq 0 && return
  # Retrieve fields from running client
  # $LOG debug : "Retrieving torrent info" "$*"
  ti="" transmission_torrent_info "$num" "$@" || return
  # Do some post handling on values just retrieved
  local field
  for field in $fields
  do
    case "$field" in
    ( num|numid|pct|have|eta|up|down|ratio|status|name ) ;;
    ( btih ) ;;
    ( progress )
        test "$progress" = "-nan%" -o "$progress" = "None" && progress=
        progress="${progress//%}"
        test -z "$progress" || {
            test "${progress/.}" != "$progress" || progress=$progress.0
        }
      ;;
    ( avail )
        test "$avail" = "-nan%" -o "$avail" = "None" && avail=
        avail="${avail//%}"
        test -z "$avail" || {
            test "${avail/.}" != "$avail" || avail=$avail.0
        }
      ;;
    ( size_tot ) ;;
    ( * ) $LOG error "$lk:transmission-info-fields" "Unknown field" "$field" 1 ;;
    esac
  done
}

# List-run helper to fetch health facts for info hash.
transmission_item_share_info () # ~ <Fields...>
{
  # Skip shares with issues and abort on unknown status
  ! ${ti_check:-false} || transmission_item_check || return

  transmission_item_share_select btih avail "$@" || return

  # Progress (and other variables) can be nan for numbers, and None for other
  # value types, if no metadata (torrent-file) is yet available.

#  test $# -eq 0 && {
#    printf 'ID: %s\nName: %s\nHash: %s\nState: %s\nAvailability: %s\n'\
#'Percentage: %s\nTotal size: %s\n' \
#          "$numid" "$name" "$btih" "$status" "$avail" "$pct" "$size_tot"
#  } || {
#    test "${1:?}" = "--" || "$@"
#  }
}

# List-run handler: Start shares using various modes.
transmission_item_start () # ~ [<Inner-handler>]
{
  ! ${skip_issues:-true} || {
    ${has_issue:-false} && return
  }
  case "$status" in ( Stopped | Finished ) ;; ( * ) return 0 ;; esac
  transmission_item_clearenv
  transmission_item_share_select "$@" || return
  # XXX: See transmission-item-pause.
  while test $# -gt 0
  do
    ti_sel=start share_select "$@" || {
      test ${_E_next:?} -eq $? && return ||
          test ${_E_break:?} -eq $_ && break ||
              return $_
    }
    shift
    test $# -eq 0 && return
  done

  ! ${DEBUG:-false} || {
    {
      transmission_item_echo
    } >&2
  }

  sa_ti_lctx_progress
  transmission_remote_do -t "$num" -s &&
      $LOG notice ":$numid" "Started share" "$lctx" ||
      $LOG error ":$numid" "Error starting share" "E$?:$lctx" $?
  started=$(( started + 1 ))
  sa_next_seq
  test $# -eq 0 || "$@"
}
transmission_item_start_pre ()
{
  started=0
}
transmission_item_start_post ()
{
  $LOG crit : "Started $started shares" "$*"
}

# List-run handler: collect trackers per share
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

# Sanity check on all of the parts read by transmission_list_runner
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
  return ${_E_next:?}
}

# Container for actions that wrap `transmission-remote -l`, for more complex
# commands and batch operations see usage of transmission-list-run.
transmission_list () # ~ <Action ...> # Filter/process clients list output
{
  test $# -gt 0 || set -- tab
  local lk=${lk:-}:transmission-list
  case "$1" in

    ( a|active )
        transmission_client_remote -l | grep ${grep_f:-} -e 'Uploading' -e 'Downloading' -e 'Seeding' ;;
    ( S|not-stopped )
        transmission_client_remote -l | grep ${grep_f:--v} '\(None\|[1-9][0-9]*\) * Stopped ' ;;
    ( idle )
        transmission_client_remote -l | grep ${grep_f:-} 'Idle' ;;
    ( e|errors|issues )
        transmission_client_remote -l | grep ${grep_f:--E} '^ *[0-9]+\* ' ;;
    ( popular )
        transmission_client_remote -l |
          grep -E '  *[0-9]+\.[0-9]+  *[0-9]+\.[0-9]+  *[1-9][0-9]*\.[0-9] ' |
          transmission_fix_item_cols | sort -k7n
      ;;
    ( s|stopped|paused )
        transmission_client_remote -l |
          grep ${grep_f:-} '\(None\|[0-9][0-9]*\) * Stopped ' ;;

    ( fix-cols )
        shift; transmission_list "$@" | transmission_fix_item_cols ;;
    ( I|ids )
        shift; transmission_list "$@" | awk '{print $1}' ;;
    ( i|items ) # ~ (<Handler>) <Id-Spec...> # Shortcut to run given handler on selected IDs
        shift; local handler=${1:-lognote}; shift
        transmission_list_run fix-cols items-by-nums "$@" -- \
            transmission_item_$handler ;;
    ( lognotes )
        shift; local handler=${1:-lognote}; shift
        transmission_list_run transmission_item_$handler
      ;;
    ( items-by-nums ) # ~ [<List-Arg...> -- ] <Id...>
        local listarg listargc
        shift; transmission_listarg "$@" && shift $listargc
        test $# -gt 0 ||
          $LOG error "$lk" "Item ID arguments expected" "" 64 || return
        transmission_list $listarg | grep "^ *\<$( grep_or "$@" )\> "
      ;;
    ( key|keys|cols ) # ~ [ <List-Arg...> -- ] <Var:Field...>
        test "$1" = "cols" && ti_row=1 || {
          test "$1" = "key" -o "$1" = "col" && ti_keymap=0 || ti_keymap=1;
        }
        local listarg listargc
        shift; transmission_listarg "$@" && shift $listargc
        test $# -gt 0 ||
          $LOG error "$lk" "Key var names or map arguments expected" "" 64 ||
          return
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
    ( count )
        : "$( transmission_list | count_lines )"
        echo $(( _ - 2 ))
      ;;

    ( * ) $LOG error "$lk" "No such action" "$1" 67
  esac
}

transmission_listarg ()
{
  listargc=$#
  local more=false
  while fnmatch "* -- *" " $* "
  do more=true
    args_q=0 args_more "$@" && shift $more_argc ; listarg="$more_args"
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

  lk=${lk:-}:list-gen transmission_list $listarg |
      lk=${lk:-}:list-run "$tl_runner" "$@"
}

# Basic reader/parser line-handler for transmission_list xtab-formatted outputs.
transmission_list_runner () # [quiet] ~ <Handler <Args...>>
{
  test $# -gt 0 || set -- transmission_item_check
  local numid pct have eta up down ratio status name itcnt=0 flcnt=0

  local bounds start_at stop_after
  test -z "${INDEX_LB:-}" -a "${INDEX_UP:-}" || {
    bounds=true start_at=${INDEX_LB:-1} stop_after=${INDEX_UP:-*}
  }

  : "${1//transmission_item_}"
  local r ret num lk _lk=$lk __lk="${lk:-}::${_//_/-}"
  ! sh_fun "$1"_pre || {
    "$1"_pre "$@" || return
  }
  $LOG info "$_lk" "Started list run" "quiet=${tlr_quiet:-${quiet:-0}}"
  while read -r numid pct have eta up down ratio status name
  do
    test "$numid" = ID && continue
    test "$numid" != "Sum:" && {

      itcnt=$(( itcnt + 1 ))
      lk=${__lk/::/[$numid]}
      ! ${bounds:-false} || {
        test "$itcnt" -ge "$start_at" && {
          test "$stop_after" = "*" || test "$itcnt" -le "$stop_after"
        } || continue
      }
      num=${numid//\*/}
      has_issue=$( test "${numid:${#num}}" = "*" && echo true || echo false )
      # Progress percentage reported in list column is an integer.
      pct=${pct//[na\/%\ ]}
      test -z "$pct" || {
          test "${pct/.}" != "$pct" || pct=$pct.0
      }

      test "$ratio" != None || ratio=
      # ratio column is reported in tenths only under 100
      test -z "$ratio" || {
          test "${ratio/.}" != "$ratio" || ratio=$ratio.0
      }
      test "$have" != None || have=
      test "$eta" != Unknown || eta=

      test ${tlr_quiet:-${quiet:-0}} -eq 1 || {
        test $(expr $itcnt % ${tl_li:-100}) -ne 0 ||
          $LOG notice "$_lk" "$itcnt items read..."
      }

      # Defer to handler, and handle return
      #lk="$_lk" \
      "$@" || { r=$?
        flcnt=$(( flcnt + 1 ))
        test $r -eq ${_E_next:?} && {
          ret=1
          continue
        }
        test ${tlr_quiet:-${quiet:-0}} -eq 1 ||
          $LOG error "$lk" "Failed on id $num" "E$r:$name"
        return $r
      }

    } || {
      test ${tlr_quiet:-${quiet:-0}} -eq 1 ||
        $LOG notice "$lk" "All items read, summary:" \
            "size:$pct items:$itcnt xfer:: up:$have down:$eta"
      break
    }
  done
  ! sh_fun "$1"_post || {
    $LOG debug "$lk" "Running post" "$_"
    "$1"_post "$@" || return
  }
  $LOG info "$lk" "Finished reading" "E${ret:-0},items:$itcnt,failures:$flcnt"
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

transmission_remote_do () # ~ <Remote-argv...>
{
  local remote rpcres
  remote="${TRANSMISSIONBT_REMOTE:-${REMOTE:-${TRANSMISSIONBT_DEFAULT_CLIENT:?}}}"
  rpcres=$(transmission_client_remote "$@") &&
  test "$rpcres" = "$remote"'/transmission/rpc/ responded: "success"' ||
    $LOG warn :remote-do "Unexpected response" "$rpcres" 1
}

transmission_remote_online () # ~
{
  local remote sessionid
  remote="${TRANSMISSIONBT_REMOTE:-${REMOTE:-${TRANSMISSIONBT_DEFAULT_CLIENT:?}}}"
  sessionid=$(REMOTE=$remote transmission_session_id)
  test -n "$sessionid"
  #curl -X HEAD -H X-Transmission-Session-Id:\ $session_id $remote/transmission/rpc/
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
          transmission_remote_do -t "${2:?}" --find "${3:?}" ;;
    ( move ) # ~ <Id-Spec> <Path>
          transmission_remote_do -t "${2:?}" --move "${3:?}" ;;
    ( s|start ) # ~ <Id-Spec>
          transmission_remote_do -t "${2:?}" --start ;;
    ( S|stop ) # ~ <Id-Spec>
          transmission_remote_do -t "${2:?}" --stop ;;

    ( * ) $LOG error "$lk" "No such action" "$1"; return 67 ;;
  esac
}


## Util

share_select ()
{
  case "${1:?}" in
    ( "+"* ) include=true exclude=false ;;
    ( "!"* ) exclude=true include=false ;;
    # ( "?"* ) exclude=false include=false ;;
    ( * ) $LOG error : "Not a selector" "$1" ${_E_GAE:?} || return ;;
  esac
  share_select_query "$1" && {
    $exclude && return ${_E_next:?} || return ${_E_break:?}
  } || true
}

share_select_info ()
{
  local qarg
  for qarg in "$@"
  do test "$qarg" != -- || break
    case "$qarg" in

    ( *avail* ) echo avail; echo progress ;;
    ( ?noseed ) echo avail ;;
    ( ?seeds|?finished* ) echo ratio ;;
    ( *"<="* | *">="* | *"<"* | *">"* | *"="* ) : "${qarg//[<>=]*}"; echo "${_:1}" ;;
    #( ?up|?down|?up-down ) : "${qarg:1}"; printf '%s\n' ${_/-/ } ;;

    #( * ) $LOG error "$lk:share-select-info" "Unknown query arg" "$qarg" 1 ;;
    esac
  done
}

share_select_query ()
{
  case "${1:?}" in
    # Does not just check wether share is (partially) available, but wether we
    # have all of it or not.
    ( ?avail|?available )
        test -n "$avail" && {
          test ${avail/.} -gt 0 && {
            test -z "${progres:-}" || test ${avail/.} -gt ${progress/.}
          }
        }
      ;;

    ( ?complete )
        test -n "$pct" -a "$pct" = "100.0" && { true
        #  test -z "${INCOMPLETE_LCUTOFF:-}"
        # test ${pct/.} -gt ${INCOMPLETE_LCUTOFF:--1}
        }
      ;;

    # These generate an additional query, so only use to double check up/down
    ( ?conn ) transmission_client_remote -t "$num" -i | grep -q \
        'Peers: connected to [1-9][0-9]*, uploading to .*, downloading from .*'
      ;;
    ( ?conn-down ) transmission_client_remote -t "$num" -i | grep -q \
        'Peers: connected to [0-9]*, uploading to .*, downloading from [1-9][0-9]*'
      ;;
    ( ?conn-up ) transmission_client_remote -t "$num" -i | grep -q \
        'Peers: connected to [0-9]*, uploading to [1-9][0-9]*, downloading from .*'
      ;;
    ( ?conn-up-down ) transmission_client_remote -t "$num" -i | grep -q \
        'Peers: connected to [0-9]*, uploading to [1-9][0-9]*, downloading from [1-9][0-9]*'
      ;;

    ( ?connected )
        test "$down" != "0.0" -o "$up" != "0.0" && return
        share_select_query "${1:0:1}conn"
      ;;

    # Can use status:downloading and status:up-down,
    # but this (double) checks for actual transfer in progress.
    ( ?downloading )
        test "$down" != "0.0" && return
        # Do double check now
        share_select_query "${1:0:1}conn-down"
      ;;
    ( ?down )
        test "$down" != "0.0" && return
      ;;

    ( ?finished )
        test "$pct" = "100.0" -a -n "$ratio" &&
        test ${ratio/.} -ge ${TARGET_SEED_RATIO/.}
      ;;
    ( ?finished-idle )
        test "$pct" = "100.0" -a "$status" = "Idle" -a -n "$ratio" &&
        test ${ratio/.} -ge ${TARGET_SEED_RATIO/.}
      ;;
    ( ?idle )
        test "$status" = "Idle"
      ;;
    ( ?incomplete|?partial )
        test -n "$pct" || return
        ! share_select_query "${1:0:1}complete"
      ;;

    ( ?meta|?metadata )
        # If everything is none, that is an indirect sign no metadata has been
        # retrieved yet.
        test -n "$pct" # -a -n "$have"
      ;;
    ( ?noseed )
        test -z "$avail" || test ${avail/.} -lt 1000
      ;;
    ( ?noconn|?unconnected )
        test "${down/.}" = "00" -a "${up/.}" = "00" || return
        transmission_client_remote -t "$num" -i | grep -q \
            'Peers: connected to 0, uploading to 0, downloading from 0'
      ;;
    ( ?nometa|?no-metadata )
        test -z "$pct" -a -z "$have"
      ;;

    ( ?queued )
        test "$status" = Queued
      ;;
    ( ?running )
        test "$status" != Queued -a "$status" != Stopped
      ;;
    ( ?seeds )
        test "$status" != Queued &&
        test "$pct" = "100.0" &&
        test -n "$ratio" &&
        test ${ratio/.} -lt ${TARGET_SEED_RATIO/.} &&
        test ${ratio/.} -gt ${STALE_SEED_RATIO:--1}
      ;;
    ( ?stopped )
        test "$status" = Stopped
      ;;
    # Checks if less than 100% is available, and wether it is downloaded
    ( ?unavail|?unavailable )
        test -z "$avail" || {
          test ${avail/.} -lt 1000 && {
            test -z "$progress" || test ${avail/.} -le ${progress/.}
          }
        }
      ;;
    ( ?uploading )
        test "$up" != "0.0" && return
        # Do double check now
        share_select_query "${1:0:1}conn-up"
      ;;
    ( ?up )
        test "${up/.}" != "00" && return
      ;;
    ( ?up-down )
        test "${up/.}" != "00" && return
        test "${down/.}" != "00" && return
      ;;

    # Helpers to use inverted selection for include or exlude query
    ( ?no-* ) ! share_select_query "${1:0:1}${1:4}" ;;
    ( ?not-* ) ! share_select_query "${1:0:1}${1:5}" ;;

    # Manage basic numeric comparison, numeric values should be specified
    # using exactly one decimal point. Equals format can also be useful for
    # strings e.g. status=Idle, but period characters are stripped.
    ( *"<="* ) : "${1/<=*}" ; var="${_:1}" ; val="${1/*<=}"
        : "${!var/.}"
        test -n "$_" && test "$_" -le "${val/.}"
      ;;
    ( *">="* ) : "${1/>=*}" ; var="${_:1}" ; val="${1/*>=}"
        : "${!var/.}"
        test -n "$_" && test "$_" -ge "${val/.}"
      ;;
    ( *">"* ) : "${1/>*}" ; var="${_:1}" ; val="${1/*>}"
        : "${!var/.}"
        test -n "$_" && test "$_" -gt "${val/.}"
      ;;
    ( *"<"* ) : "${1/<*}" ; var="${_:1}" ; val="${1/*<}"
        : "${!var/.}"
        test -n "$_" && test "$_" -lt "${val/.}"
      ;;
    ( *"="* ) : "${1/=*}" ; var="${_:1}" ; val="${1/*=}"
        : "${!var/.}"
        test -n "$_" && test "$_" = "${val/.}"
      ;;

    ( * ) $LOG error : "No such ${ti_sel:-selection} mode" "$1" 1 || return ;;
  esac
}

#
