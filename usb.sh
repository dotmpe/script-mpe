#!/usr/bin/env bash

set -euo pipefail
shopt -s nullglob

IGNORE_GREP=( -v
  -e '^BASH'
  -e '^DIRSTACK'
  -e '^FUNCNAME'
  -e '^RANDOM'
  -e '^SRANDOM'
  -e '^UID'
  -e '^EUID'
  -e '^COMP'
  -e '^LINENO'
  -e '^HIST'
  -e '^IFS'
  -e '^OPT'
  -e '^PATH'
  -e '^PPID'
  -e '^PS[01234]'
  -e '^PIPESTATUS'
  -e '^PWD'
  -e '^SECONDS'
  -e '^SHELL'
  -e '^SHLVL'
  -e '^TERM'
  -e '^USER_SCRIPT_TIMEOUT'
  -e '^IGNORE_GREP'
  -e '^device_envfile_spec'
  -e '^_$'
)

device_envfile_spec='/run/user/${USB_UID:?}/usb_new.${node_name:?}.env'

: "${USER_SCRIPT_TIMEOUT:=5}"

wait_for_file_with_timeout ()
{
  local to=$(( $(date +%s) + ${2:-1} ))
  while [[ ! -f "$1" ]]; do
    sleep .1
    (( $(date +%s) > to )) && return 1
  done
}

failerr ()
{
  local stat=${2:-$?}
  : about "Output message and set or pass-trough non-zero status (input 256 for 0)"
  : extended "Default is 1, and cannot be 0."
  : extended "The number is truncated to 255 and then rolls over again, so 256 equals 0, etc."
  : input "${1:?$FUNCNAME: Failure message, $ENV_CTX}"
  ((stat)) || stat=1
  if (( stat > 255)); then
      ((stat-=256))
  fi
  >&2 echo "$1"
  return ${stat}
}

guess_icon ()
{
  icons=(
    drive-removable-media
    drive-harddisk-usb
    drive-multidisk
    drive-harddisk
    drive-optical

    media-removable
    media-flash
    #action/media-record
    #action/media-eject

    # padlock
    #changes-allow
    #changes-prevent
  )
}

help ()
{
  echo "Commands:"
  sed 's/^/  /' < <( grep -Po '^[a-z_-]+(?= *\(\))' "$0")
  echo "Output:"
}

helper ()
{
  case "${1:?}" in

    ( browse-icons )
         targets .chdir_theme .feh_preview
       ;;

    ( * ) failerr "$FUNCNAME: Unmatched: ${*@Q}"
  esac
}

if_ok ()
{
  return
}

action_menu ()
{
  yad \
    --width=200 \
    --height=150 \
    --posx=50 --posy=50 \
    --list --title="New USB device ${1:-(${ID_VENDOR:-no-vendor} ${ID_USB_MODEL:-no-model})}" \
    --column="Actions:" "Open Serial" "Upload Sketch" "Ignore"
}

event ()
{
  case "${1:?}" in

    ( --user-notify )
        local node_name=$2 dev_env icon
        targets .load_env .rm_env .guess_icon &&
        notify-send \
          --app-name=USB \
          --urgency=normal \
          --icon=$icon \
          --category=device.added \
          "USB $kernel_name" "Device attached: ${ID_VENDOR:+$ID_VENDOR ${ID_MODEL:--} }(${SUBSYSTEM-(no_subsys)})"
      ;;

    ( --user-scan ) # TODO: implement scripts and heuristics
        echo Found device $2, reading data...
        local node_name=$2 dev_env
        targets .load_env .rm_env .guess_icon || return

        # TODO: run menu for uart, serial, dpf, udf, android, storage, hub,
        # camera, ethernet, wifi, bluetooth, keyboard, mouse, joystick, gamepad
        # i2c/smbus, etc.
        echo Starting usb-$USB_PROFILE user menu
        set -m
        set +u

        . /usr/share/uc/us-host-profile.sh &&
        eval "${US_ENV_INIT:?}" &&
        PY_VENV_NAME=script-mpe &&
        pyvenv_start &&
        : || failerr "E$? loading user scan session" || return

        local ppid=$(ps -o ppid= $$)
        local -n port=${USB_PROFILE^^}_PORT

        trigger --kill-on-remove "$ppid" "$port" "$dev_env" &
        tmenu.sh menu usb-$USB_PROFILE &
      ;;

    ( --new-device )
        shift
        local kernel_name=$1 device_node=$2 dev_path=$3
        local node_name=${device_node//\//-}
        local varname{,s}
        mapfile -t varnames < <(compgen -A variable | grep "${IGNORE_GREP[@]}" -e '^varname' )
        logger -p user.notice -t usb:new-device "$SUBSYSTEM ${ACTION-} event: new USB device $1 (node $2, path $3)"
        local env{,out}
        : "${USB_UID:=1000}"
        . <(echo "envout=$device_envfile_spec") &&
        for varname in "${varnames[@]}"; do
          : "${!varname-}"
          env+="$varname=${_:+${_@Q}}"$'\n'
        done
        echo "$env" >| "$envout"
        #logger -p user.notice -t usb:new-device "$SUBSYSTEM ${ACTION-} event: new USB $1 device handler done ($envout)"
      ;;

    ( --new-serial )
        shift
        #event --log-envnames $1
        #logger -p user.notice "$SUBSYSTEM ${ACTION-} event: /dev/$1: new UART $UART_PORT $UART_PRODUCT_ID $UART_SERIAL_ID"
        event --new-device $1 uart SUBSYSTEM DRIVER DEV{NUM,TYPE} PRODUCT 'ID_*'
        logger -p user.notice -t usb "$SUBSYSTEM ${ACTION-} event: /dev/$1: new serial: $ID_VENDOR_FROM_DATABASE $ID_MODEL_FROM_DATABASE${*:+ ($*)}"
      ;;

    ( --lost-serial )
        logger -p user.notice -t usb "$SUBSYSTEM ${ACTION-} event: /dev/$2: lost serial"
      ;;

    ( --log-envnames )
        shift
        : "$(tr $'\n' ' ' < <(compgen -A variable | grep "${IGNORE_GREP[@]}" ))"
        logger -p user.notice -t usb:envnames "$SUBSYSTEM ${ACTION-} event:${*:+ $*: }$_"
      ;;

    ( --log-generic-id )
        shift
        local v m="${DRIVER-} [e:$EUID u:$UID v:$UDEV_DATABASE_VERSION]"
        for v in $(compgen -A variable -X '!ID_*')
        do
          : "${!v}"
          m+=" $v=${_@Q}"
        done
        logger -p user.notice -t usb:generic-id "$SUBSYSTEM $ACTION event:${*:+ $*:} $m"
      ;;

    ( --log-generic-model )
        shift
        : "$ID_MODEL $ID_MODEL_FROM_DATABASE ($ID_MODEL_ID) [b:$ID_BUS p:$ID_PATH t:$ID_TYPE ud:$ID_USB_DRIVER] [$ID_REVISION $ID_SERIAL]"
        logger -p user.notice -t usb:generic-model "$SUBSYSTEM ${ACTION-} event:${*:+ $*:} $_"
      ;;

    ( --log-generic-usb )
        shift
        local v m="${DRIVER-} [${ID_PATH-} b:${ID_BUS-} t:${ID_TYPE-} m:${ID_MODEL-} r:${ID_REVISION-}] [e:$EUID u:$UID v:$UDEV_DATABASE_VERSION]"
        for v in $(compgen -A variable -X '!*USB*')
        do
          : "${!v}"
          m+=" $v=${_@Q}"
        done
        logger -p user.notice -t usb:generic "$SUBSYSTEM $ACTION event:${*:+ $*:} $m"
      ;;

    ( --log-generic-usb-serial )
        shift
        local v m="${DRIVER-} [$DEVPATH] [e:$EUID u:$UID v:$UDEV_DATABASE_VERSION]"
        logger -p user.notice -t usb:serial:generic "$SUBSYSTEM $ACTION event:${*:+ $*:} $m"
      ;;

    * ) return ${_E_nsk:-67}
  esac
}

trigger ()
{
  case "${1:?}" in

    ( --found )
        local node_name=$2 dev_env
        targets .load_env &&
        if [[ ${USB_PROFILE:+set} ]]; then
          # XXX: interactive
          command urxvt -title "New USB $kernel_name" \
            -name 'usb/helper-udev-trigger/aux' \
            -hold -geometry 60x22+1020+550 \
            -e /srv/home-local/bin/usb.sh event --user-scan "${2}"
        else
          event --user-notify "$2"
        fi
      ;;

    ( --kill-on-remove )
      : input "${2:?PID}"
      : input "${3:?Port device}"
      : input "${4:?Cache file}"
        while [[ -e "$3" ]]
        do
          sleep 1
        done
        echo "Exiting (port lost)"
        sleep 1
        rm -f "$4"
        kill -9 "$2"
      ;;

    * ) return ${_E_nsk:-67}
  esac
}

info ()
{
  TODO
  for x in /sys/bus/usb/devices/${1:?}/
  do
    false
  done
}

list ()
{
  local {bus,usb}num device usb{dev,ver,sp}
  for usbnum in /sys/bus/usb/devices/usb[0-9]*/busnum
  do
    busnum=$(< "$usbnum")
    device=$(dirname "$usbnum")
    usbdev=$(< "$device/dev")
    usbver=$(< "$device/version")
    usbsp=$(< "$device/speed")
    [[ ! -e "$device/product" ]] && usbprod= || usbprod=$(< "$device/product")
    echo "USB bus $busnum $usbprod (version $usbver, speed $usbsp, device $usbdev)"

    for usbnum2 in $device/*/busnum
    do
      device2=$(dirname "$usbnum2")
      numid=$(basename $device2)
      usbdev=$(< "$device2/dev")
      usbver=$(tr -d ' ' < "$device2/version")
      usbsp=$(< "$device2/speed")
      [[ ! -e "$device2/product" ]] && usbprod= || usbprod=$(< "$device2/product")
      [[ -e /sys/bus/usb/drivers/usb/$numid ]] && stat=" " || stat=" (offline) "
      echo "  $numid dev $usbdev ver $usbver speed $usbsp${stat}product $usbprod"
    done
  done
}

targets ()
{
  :
  while (( $# > 0 ))
  do case "${1:?}" in

    ( .chdir_theme )
        [[ ${icon_theme:+set} ]] || targets .get_icon_theme || return
        pushd /usr/share/icons/$icon_theme
      ;;

    ( .feh_preview )
        pushd 64x64/ &&
        fzf --preview 'echo "See preview window for" {}; feh -g 300x300 -Z -. --title feh-preview --class view/icon/aux {}'
      ;;

    ( .get_icon_theme )
        if_ok "$(gsettings get org.gnome.desktop.interface icon-theme)" &&
        icon_theme=${_:1:-1} &&
        >&2 declare -p icon_theme
      ;;

    ( .guess_icon )
        case "$SUBSYSTEM" in
          ( block ) icon=media-removable ;;
          ( scsi_generic ) icon=drive-removable-media ;;
          ( input )
              if [[ ${ID_INPUT_KEYBOARD:-} == 1 ]]; then icon=input-keyboard
              elif [[ ${ID_INPUT_MOUSE:-} == 1 ]]; then icon=input-mouse
              elif [[ ${ID_INPUT_JOYSTICK:-} == 1 ]]; then icon=input-gaming
              else icon=input-tablet
              fi
            ;;
          ( * ) #icon=devices/device_usb
            # XXX: this ai
            icon=/usr/share/icons/ePapirus-Dark/128x128/devices/device_usb.svg
          ;;
        esac
      ;;

    ( .load_env )
        : "${USB_UID:=$UID}"
        . <(echo "dev_env=$device_envfile_spec") &&
        wait_for_file_with_timeout "$dev_env" $USER_SCRIPT_TIMEOUT ||
          failerr "Timeout for usb.sh event ${*@Q} waiting for env file" || return
        . "$dev_env"
      ;;

    ( .rm_env )
        rm -rf "$dev_env"
      ;;

    ( * ) failerr "$FUNCNAME: Unmatched target${1@Q}"
  esac &&
    shift || return
  done
}

on ()
{
  echo "${1:?}" |
      sudo -p "Password to enable USB port '${1:?}' (%u->%U): " \
      tee /sys/bus/usb/drivers/usb/bind
}

off ()
{
  echo "${1:?}" |
      sudo -p "Password to disable USB port '${1:?}' (%u->%U): " \
      tee /sys/bus/usb/drivers/usb/unbind
}

"$@"
