#!/bin/sh


toggle_shuttle() {
  `osascript -sso - "$1" > /private/tmp/SshuttleToggle <&- <<EOF

on run argv
  copy argv to stdout
  set enable to item 1 of argv

  if enable is equal to "" then
    set enable to "Connect"
  end if

  delay 0
  with timeout of 20 seconds

    tell application "System Events"
      tell process "Sshuttle"

        -- Get name of taskbar button:
        #get name of menu bar item 1 of menu bar 1

        click first menu bar item of first menu bar

        -- Get name of taskbar button:
        #get properties of every menu bar

        -- List all items in Sshuttle menu
        #get properties of every menu item of every menu of menu bar item of every menu bar

        -- Get the title of the item we will cick
        set action_done to name of menu item 1 of menu 1 of menu bar item 1 of menu bar 1

        if action_done starts with enable then
          -- Click first menu item of Sshuttle menu
          click first menu item of first menu of menu bar item of first menu bar
          copy action_done to stdout
        else
          copy "Already " & enable & "'ed" to stdout
        end if

      end tell
    end tell

  end timeout

end run

EOF`

  enabled=$(cat /private/tmp/SshuttleToggle)
  case "$enabled" in *error:* )
      warn "Sshuttle: $enabled";;
    * )
      std_info "Sshuttle: $enabled";;
  esac
}

toggle_openvpn()
{
  sudo rm -rf /private/tmp/OpenVpn*

  local stat=
  enabled_openvpn $2 || stat=$?
  case $1 in
    on )
        case "$stat" in
          2 | 1 )
              note "Enabling VPN '$2'"
            ;;
          * )
              return 0
            ;;
        esac
      ;;
    off )
        case "$stat" in
          1 )
              return 0
            ;;
          * )
              note "Disabling VPN '$2'"
            ;;
        esac
      ;;
    * ) error "Unknown target state for OpenVPN: '$1'" 1 ;;
  esac

  `osascript -sso - "$1" "$2" > /private/tmp/OpenVpnToggle <&- <<EOF
on run argv
  copy argv to stdout
  set enable to item 1 of argv
  set server to item 2 of argv
  if enable is equal to "on" then
    tell application "Tunnelblick"
      connect server
    end tell
  else
    tell application "Tunnelblick"
      disconnect server
    end tell
  end if
end run
EOF`
  case $1 in on )
      while ! enabled_openvpn "$2"
      do
        # Reduce verbosity a bit, but break more often
        sleep 5
        enabled_openvpn "$2" && break
        echo "Waiting for VPN $2"
        sleep 5
        enabled_openvpn "$2" && break
        sleep 5
      done
    ;; esac
}

enabled_openvpn()
{
  test -n "$1" || error "Need openvpn config name" 1

  `osascript -sso - "$1" > /private/tmp/OpenVpnStatus <&- <<EOF
on run argv
  set server to item 1 of argv
  tell application "Tunnelblick"
    set status to state of first configuration where name = server
    copy status to stdout
  end tell
end run
EOF`

  vpn_status="$(cat /private/tmp/OpenVpnStatus)"
  note "VPN status: $vpn_status"
  case "$vpn_status" in

    '"SLEEP"' | '"EXITING"' )
        return 1 # closed/closing
      ;;

    '"TCP_CONNECT"' | '"GET_CONFIG"' | '"ASSIGN_IP"' | '"PASSWORD_WAIT"' | '"AUTH"' | '"RESOLVE"' )
        return 2 # wait
      ;;

    '"CONNECTED"' )
        return
      ;;

    * )
        error "Unknown VPN state: $(echo $(cat /private/tmp/OpenVpnStatus))"
        return 3
      ;;

  esac
  note "VPN status=$vpn_status"
}
