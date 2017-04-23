

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


darwin_profile_xml()
{
  local xml=$(setup_tmpf .xml) datatype=$1; shift
  system_profiler $datatype -xml > $xml
  echo $xml
}

darwin_profile_tab()
{
  local xml=$(darwin_profile_xml "$@"); shift
  darwin.py plist-items $xml "$@"
  rm $xml
}

darwin_profile_dump()
{
  local xml=$(darwin_profile_xml "$@"); shift
  darwin.py plist-dump $xml
}

darwin_disk_table()
{
  #darwin_profile_tab SPStorageDataType mount_point bsd_name volume_uuid file_system
  xml=$(darwin_profile_xml "SPStorageDataType")
  darwin.py plist-dump $xml
  #darwin.py spstorage-disk $xml mount_point bsd_name volume_uuid file_system
  return

  # List data on main SATA disk(s)
  xml=$(darwin_profile_xml "SPSerialATADataType")
  echo '#SPSerialATADataTypel: bsd-name device-serial size-in-bytes device-model'
  darwin.py spserialata-disk $xml disk0 bsd_name device_serial size_in_bytes device_model
  #darwin.py spserialata-disk-part $xml mount_point bsd_name volume_uuid size_in_bytes _name
  echo

  # List data on USB disk(s)
  #xml=$(darwin_profile_xml "SPUSBDataType")
  #echo '#SPUSBDataType: bsd-name serial-num size-in-bytes manufacturer vendor-id product-id'
  #darwin.py spusb-disk $xml disk8 bsd_name serial_num size_in_bytes manufacturer vendor_id product_id
}

