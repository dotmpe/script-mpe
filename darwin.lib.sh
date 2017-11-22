#!/bin/sh


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
  sudo mv $id.service $LLA
  sudo launchctl load $LLA/$id.service
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
  system_profiler $datatype -xml > $xml
  echo $xml
}

# XXX: darwin-profile-tab: unused
darwin_profile_tab()
{
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
  darwin_mounts | cut -d ' ' -f 1 | while read mp
  do
    test -e $mp/.volumes.sh || {
      warn "Unregistered disk/volume at mount '$mp'"
      continue
    }
    eval $( sed 's/^volumes_main_//g' $mp/.volumes.sh )
    printf -- "$disk_index\t$part_index\t"
    df $mp | tail -n +2 | tr -s ' ' '\t'
  done
}

darwin_disk_info()
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


# Main

case "$0" in "" ) ;; "-"* ) ;; * )

  # Do nothing if loaded by lib-load
  test -n "$__load_lib" || {

    # Otherwise set action with env __load
    test -n "$__load" || {

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
          #darwin_lib_load || ...
          type "$1" >/dev/null 2>&1 || {

            echo "Error loading $scriptname: $1" 1>&2
            exit 1
          }
          __load=boot . ./util.sh
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
