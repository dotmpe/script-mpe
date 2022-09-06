#!/bin/sh

# BSD/Darwin specific

darwin_lib_load()
{
  : "${uname:=$(uname -s)}"
  test -n "${xattr-}" || xattr=xattr-2.7
  test -n "${STATUSDIR_ROOT-}" || STATUSDIR_ROOT=$HOME/.statusdir
  test -d "${STATUSDIR_ROOT-}logs/$hostname" ||
      mkdir -p "${STATUSDIR_ROOT}logs/$hostname"
  test -n "${sleeplog-}" || sleeplog=$HOME/.statusdir/logs/$hostname/sleep.log
  test -n "${locklog-}" || locklog=$HOME/.statusdir/logs/$hostname/lock.log
}

darwin_locklog_env()
{
  locklog_raw=$HOME/.statusdir/logs/$hostname/lock-raw-${1}.log
}

setup_launchd_service()
{
  test -n "$base" || error "base" 1
  test -n "$program" || program=$0
  test -n "$port" || port=18083
  id=com.dotmpe.$base
  cd $TMPDIR
  { cat - <<EOM
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Disabled</key>
  <true/>
  <key>KeepAlive</key>
  <false/>
  <key>Label</key>
  <string>$id<string>
  <key>ProgramArguments</key>
  <array>
    <string>$program</string>
    <string>spawn</string>
  </array>
  <key>StandardErrorPath</key>
  <string>/dev/null</string>
  <key>StandardOutPath</key>
  <string>/dev/null</string>
  <!--
  <key>Sockets</key>
    <dict>
    <key>Listeners</key>
    <dict>
      <key>SockServiceName</key>
      <string>$port</string>
      <key>SockType</key>
      <string>stream</string>
      <key>SockFamily</key>
      <string>IPv4</string>
    </dict>
  </dict>
  -->
</dict>
</plist>
EOM
} > $id.service
  LLA=$HOME/Library/LaunchAgents/
  test -w "$LLA" && pref= || {
    warn "setup-launchd-service: Using sudo to access $LLA"
    pref=sudo
  }
  warn "Using sudo to move to $LLA"
  $pref mv $id.service $LLA
  $pref launchctl load $LLA/$id.service
}


start_launchd_service()
{
  test -n "$base" || error "base" 1
  id=com.dotmpe.$base
  sudo launchctl enable $id.service
  sudo launchctl start $id.service
}


# Retrieve OS/X plist XML from system_profiler
darwin_profile_xml()
{
  local xml=$(setup_tmpf .xml) datatype=$1; shift
  xml=$HOME/.statusdir/system/$hostname/$datatype.xml
  mkdir -vp $(dirname $xml)
  test -e $xml || system_profiler $datatype -xml > $xml
  echo $xml
}

# XXX: darwin-profile-tab: unused
darwin_profile_tab()
{
    return 1
  local xml=$(darwin_profile_xml "$@"); shift
  darwin.py plist-items $xml "$@"
  rm $xml
}

# Dump system_profiler XML to YAML on stdout
darwin_profile_dump()
{
  test -n "$1" || set -- SPStorageDataType
  local xml=$(darwin_profile_xml "$@")
  darwin.py plist-dump $xml
}

# darwin-mounts: List device, BSD-name, UUID and description of fs-type
darwin_bsd_mounts()
{
  debug "Dumping SPStorageDataType profile"
  #darwin_profile_tab SPStorageDataType mount_point bsd_name volume_uuid file_system
  xml=$(darwin_profile_xml "SPStorageDataType")
  darwin.py spstorage-disk $xml "" mount_point bsd_name volume_uuid file_system
}

darwin_mounts()
{
  darwin_bsd_mounts | while read mp name uuid fs
  do printf -- "$mp\t/dev/$name\t$uuid\t$fs\n"
  done
}

# darwin-mount-stats: combine darwin-mounts with disk-idx/part-idx and df data
darwin_mount_stats()
{
  echo "#disk,part,dev,512-blocks,Used,Avail,Capacity,iused,ifree,iusedPct,mp"
  darwin_mounts | cut -d "	" -f 1 | while read mp a
  do
    test -z "$a" || error "reading '$mp $a'" 1
    test -e "$mp/.volumes.sh" || {
      warn "Unregistered disk/volume at mount '$mp'"
      continue
    }
    eval $( sed 's/^volumes_main_//g' $mp/.volumes.sh )
    printf -- "$disk_index\t$part_index\t"
    df $mp | tail -n +2 | tr -s ' ' '\t'
  done
}

darwin_disk_info() # TODO
{
  xml=$(darwin_profile_xml "SPStorageDataType")
  #for disk in disk0 disk1 disk2 disk3 disk4 disk5 disk6 disk7 disk8
  #do
  #  #echo $disk
  #  darwin.py spstorage-disk $xml $disk bsd_name volume_uuid file_system
  #done

  darwin_sata_data
  darwin_usb_data
}

darwin_sata_data()
{
  ## List data on main SATA disk(s)
  xml=$(darwin_profile_xml "SPSerialATADataType")
  echo '#SPSerialATADataTypel: bsd-name device-serial size-in-bytes device-model'
  darwin.py spserialata-disk $xml "" bsd_name device_serial size_in_bytes device_model
  #darwin.py spserialata-disk-part $xml mount_point bsd_name volume_uuid size_in_bytes _name
}

darwin_disk_table()
{
  #disk_local "$1" NUM DEV DISK_ID DISK_MODEL SIZE TABLE_TYPE MNT_C
  for disk in $(disk_list)
  do
    system_profiler SPSerialATADataType | grep -q $(basename $disk)'\>' && {
      echo SerialATA disk=$disk
    } || {
      grep -q $(basename $disk)'\>' $darwin_disk_tab && {
        echo SPStorageDataType disk=$disk
      } ||
        stderr warn "Not in system-profiler db: $disk"
      continue
    }
  done
}

darwin_usb_data()
{
  ## List data on USB disk(s)
  xml=$(darwin_profile_xml "SPUSBDataType")
  echo '#SPUSBDataType: bsd-name serial-num size-in-bytes manufacturer vendor-id product-id'
  darwin.py spusb-disk $xml "" bsd_name serial_num size_in_bytes manufacturer vendor_id product_id
}

darwin_wherefrom()
{
  $xattr -p com.apple.metadata:kMDItemWhereFroms "$1" \
		| xxd -r -p \
		| plutil -convert xml1 -o - - \
		| grep string | sed 's/^.*<string>\(.*\)<\/string>.*/\1/' \
		| tr -d "\r" \
		| {
		    read url ; read via ; echo "url='$url' via='$via' "
        } \
        | xml-decode.py -
}


## Htd subcommands

htd_darwin_list()
{
  system_profiler -listDataTypes
}

htd_darwin_profiles()
{
  for dtype in "$@"
  do
      note "Type: $dtype"
      system_profiler $dtype
  done
}

# NOTE: empty
htd_darwin_dev()
{
    system_profiler -detailLevel full SPDeveloperToolsDataType
}

htd_darwin_hw()
{
    system_profiler -detailLevel full SPHardwareDataType
}

htd_darwin_diag()
{
    system_profiler -detailLevel full SPDiagnosticsDataType
}

htd_darwin_power()
{
    system_profiler -detailLevel full SPPowerDataType
}

htd_darwin_tb()
{
    system_profiler -detailLevel full SPThunderboltDataType
}

# NOTE:
htd_darwin_storage()
{
    system_profiler -detailLevel full SPStorageDataType
}


htd_darwin_list_profiles()
{
  system_profiler -listDataTypes
}


htd_darwin_profile()
{
  local grep="$1"
  htd_darwin_list_profiles | while read dtype
  do
    test -n "$grep" &&  {
      system_profiler $dtype | eval grep "$grep" &&
        echo "$dtype for $grep" || true
    } || {
      system_profiler $dtype
    }
  done
}

# Darwin power-management
htd_darwin_sleeplog_update()
{
  mv "$sleeplog" "$sleeplog.tmp" || touch "$sleeplog.tmp"
  { cat "$sleeplog.tmp"
    pmset -g log |
      $ggrep "^[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]" |
      $ggrep '[0-9][0-9]\ \<\(Sleep\|Wake\)\ \ '
  } | sort -u > "$sleeplog"
  rm "$sleeplog.tmp"
}

htd_darwin_sleeplog()
{
  htd_darwin_sleeplog_update
  local state= start= duration=
  nowts="$($gdate +"%s")"
  cat "$sleeplog" | while read -r date time tzd domain_msg_rest
  do
    domain="$(echo $(echo "$domain_msg_rest" | cut -c1-21))"
    case "$domain" in Sleep|Wake ) ;; * ) continue ;; esac
    ts="$(gdate -d "${date}T${time}${tdz}" +"%s")"
    day="$(gdate -d "${date}T${time}${tdz}" +"%a")"
    msg="$(echo "$domain_msg_rest" | cut -c22-)"
    ts_rel_multi "$(( $nowts - $ts ))" hours minutes seconds ; time_ago="$dt_rel"

    test "$domain" = "$state" || {
      test -n "$start" && {
        ts_rel_multi "$(( $ts - $start ))" hours minutes seconds
        note "$day, $time_ago ago: state $state ended, lasted $dt_rel: new state: $domain: $msg"
      } || {
        note "$day, $time_ago ago: initial state $domain"
      }
      start="$ts"
      state="$domain"
    }
  done
}

htd_darwin_sleeplog_summary()
{
  local nowts="$($gdate +"%s")"
  read_nix_style_file "$sleeplog" | while read -r date time tzd state descr
  do
    s="$($gdate -d "${date}T${time}${tzd}" +"%s" )"
    ts_rel_multi "$(( $nowts - $s ))" hours minutes seconds
    note "${state}, ${dt_rel} ago"
  done
}

htd_darwin_locklog_list()
{
  {
    test -n "$1" && {
      test -n "$2" && {
        sudo log show --start "$1" --end "$2"
      } || {
        sudo log show --start "$1"
      }
    } || {
      sudo log show
    }
  } | grep gIOScreenLockState
}

htd_darwin_locklog_update_day()
{
  test -n "$1" &&
      date="$($gdate -d "$1" +"%Y-%m-%d")" || date="$($gdate +"%Y-%m-%d")"
  darwin_locklog_env "$date"
  set -- "$1" "$locklog_raw"

  day_end="$($gdate -d "$date" -d "+1 day" +"%s")"
  test -e "$2" && {
    test $(filemtime "$2") -gt $day_end && return
  }

  end="$($gdate -d "$date" -d "+1 day" +"%Y-%m-%d")"
  test -e "$2" && mv "$2" "$2.tmp" ||
      echo "# Timestamp                     Thread     Type        Activity             PID    TTL  Description" > "$2.tmp"
  {
    grep -v "^$date" "$2.tmp"
    htd_darwin_locklog_list "$date" "$end"
  } > "$2.new"
  test -e "$2" && {
    diff -q "$2" "$2.new" && mv "$2.new" "$2" || rm "$2.new"
  } || {
    mv "$2.new" "$2"
  }
  rm "$2.tmp"
}

htd_darwin_locklog_update()
{
  # Update yesterday and today
  htd_darwin_locklog_update_day -1day
  htd_darwin_locklog_update_day
}

htd_darwin_locklog_raw() # Date-Tag
{
  test -n "$locklog_raw" || {
      test -n "$1" &&
          date="$($gdate -d "$1" +"%Y-%m-%d")" || date="$($gdate +"%Y-%m-%d")"
      darwin_locklog_env "$date"
  }
  lib_load table
  fixed_table_cuthd "$locklog_raw" $(fixed_table_hd_ids "$locklog_raw")
  fixed_table "$locklog_raw" "$cutf"
}

darwin_locklog_rawstate()
{
    case "$state" in
        1 ) echo unlocked ;;
        3 ) echo locked ;;
    esac
}

htd_darwin_locklog_raw2state()
{
  while read sh_props
  do
    eval $sh_props
    fnmatch "*: gIOScreenLockState *" "$Description" || continue
    new_lock_state="$( echo "$Description" | sed 's/^.* gIOScreenLockState \([0-9]*\).*/\1/' )"
    test "$new_lock_state" = "$state" && continue

    ts="$(gdate -d "${Timestamp}" +"%s")"
    test -z "$start" || {
        ts_rel_multi "$(( $ts - $start ))" hours minutes seconds ; duration="$dt_rel"
        state_str=$(darwin_locklog_rawstate "$state")
        echo $($gdate -d "@${start}" --iso-8601=seconds) $state_str $duration
    }

    # XXX: verbose
    #day="$(gdate -d "${Timestamp}" +"%a")"
    #ts_rel_multi "$(( $nowts - $ts ))" hours minutes seconds ; time_ago="$dt_rel"
    #test -n "$state" && {
    #  info "$day, $time_ago ago: new state '$state->$new_lock_state'"
    #} || {
    #  info "$day, $time_ago ago: initial state '$new_lock_state'"
    #}

    start="$ts"
    state="$new_lock_state"
  done

  nowts="$($gdate +"%s")"
  ts_rel_multi "$(( $nowts - $start ))" hours minutes seconds
  state_str=$(darwin_locklog_rawstate "$state")
  note "Current: $state_str ($dt_rel)"
}

htd_darwin_locklog_summary() #
{
  local nowts="$($gdate +"%s")"
  read_nix_style_file "$locklog" | while read -r datetime state period
  do
    s="$($gdate -d "$datetime" +"%s" )"
    note "$state duration: $period, $( fmtdate_relative "$s" )"
  done
}

htd_darwin_locklog() #
{
  note "Updating raw event log(s)..."
  htd_darwin_locklog_update

  test -e "$locklog" && {
    note "Updating lock log..."
    test "$locklog" -nt "$locklog_raw" || {

      note "Rebuilding from today's raw..."
      mv "$locklog" "$locklog.tmp"
      {
        grep -v "^$($gdate +"%Y-%m-%d")" "$locklog.tmp"
        htd_darwin_locklog_raw | htd_darwin_locklog_raw2state
      } | sort -u > "$locklog"
      rm "$locklog.tmp"
    }
  } || {
    note "Initializing lock log..."
    for locklog_raw in ${STATUSDIR_ROOT}logs/$hostname/lock-raw-*.log
    do note "Parsing '$(basename "$locklog_raw")'..."
      htd_darwin_locklog_raw | htd_darwin_locklog_raw2state
    done > "$locklog"
  }

  #test -n "$2" &&  {
  #  grep "^$2" "$3"
  #} || {
  #  tail -n 5 "$3"
  #}
}

darwin_uptime()
{
  test -n "$nowts" || nowts="$($gdate +"%s")"
  # usec? sysctl -n kern.boottime | cut -d' ' -f7
  echo $(( $nowts - $(darwin_boottime) ))
}

darwin_boottime()
{
  sysctl -n kern.boottime | tr -d ',' | cut -d' ' -f4
}


## Main

case "$0" in "" ) ;; "-"* ) ;; * )

  # Do nothing if loaded by lib-load
  test -n "${__load_lib-}" || {

    # Otherwise set action with env __load
    test -n "${__load-}" || {

      # Sourced or executed without __load* env.

      # If executed, there may be arguments passed. Bourne shell does not
      # support argument passing to sourced scripts (Bash can and others
      # probably).

      case "$1" in

        load|ext|load-ext ) __load=ext ;;
        * ) __load=boot ;;

      esac
    }
    case "$__load" in

      boot )
          test -n "$scriptpath" || scriptpath="$(dirname "$0")/script"
          test -n "$scriptname" || scriptname="$(basename "$0" .sh)"
          test -n "$verbosity" || verbosity=5
          export base=$scriptname
          darwin_lib_load
          type "$1" >/dev/null 2>&1 || {

            echo "Error loading $scriptname: $1" 1>&2
            exit 1
          }
          util_mode=boot . ./util.sh
          lib_load std sys os
        ;;

    esac
    case "$__load" in

      ext ) ;; # External include, do nothing

      boot )
          "$@" || exit $?
        ;;

      * ) echo "Illegal darwin.lib load action '$__load/$*'" >&2 ; exit 1 ;;

esac ; } ;; esac
# Id: script-mpe/
