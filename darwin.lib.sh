

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


