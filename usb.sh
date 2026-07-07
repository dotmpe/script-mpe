#!/usr/bin/env bash

set -euo pipefail
shopt -s nullglob

IGNORE_VARS=( -X 'BASH*' -X RANDOM -X PWD -X SHLVL -X SRANDOM -X 'COMP*' -X LINENO -X IFS -X 'OPT*' -X PATH -X PPID -X 'PS[01234]' -X PIPESTATUS )

help ()
{
  echo "Commands:"
  sed 's/^/  /' < <( grep -Po '^[a-z_-]+(?= *\(\))' "$0")
  echo "Output:"
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

    ( --user-scan )
        echo Found device $2, reading data...
        local dev_env=/run/user/$UID/${2}.env
        while [[ ! -s $dev_env ]]
        do
          sleep 1
        done
        . "$dev_env"
        #rm -f "$dev_env"
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
        local -n port=${2^^}_PORT
        local var val env pat filters=( "!${2^^}*" )
        env+="USB_PROFILE=$2"$'\n'
        for pat in "${@:3}"
        do filters+=( "!$pat" )
        done
        logger -p user.notice "$SUBSYSTEM ${ACTION-} event: new /dev/$1: $2 device"
        for pat in "${filters[@]}"
        do
          for var in $(compgen -A variable -X "$pat")
          do
            : "${!var-}"
            val="${_@Q}"
            [[ $var == ${2^^}* ]] && {
              env+="$var=$val"$'\n'
            } ||
              env+="${2^^}_$var=$val"$'\n'
          done
        done
        # should want to check with cache but running in minimal env here
        echo "$env" >| /run/user/${USB_UID:-1000}/${port//[^A-Za-z0-9_-]/-}.env
        #logger -p user.notice "$SUBSYSTEM ${ACTION-} event: /dev/$1: device done"
      ;;

    ( --new-serial )
        shift
        #event --log-envnames $1
        #logger -p user.notice "$SUBSYSTEM ${ACTION-} event: /dev/$1: new UART $UART_PORT $UART_PRODUCT_ID $UART_SERIAL_ID"
        event --new-device $1 uart SUBSYSTEM DRIVER DEV{NUM,TYPE} PRODUCT 'ID_*'
        logger -p user.notice "$SUBSYSTEM ${ACTION-} event: /dev/$1: new serial: $ID_VENDOR_FROM_DATABASE $ID_MODEL_FROM_DATABASE${*:+ ($*)}"
      ;;

    ( --lost-serial )
        logger -p user.notice "$SUBSYSTEM ${ACTION-} event: /dev/$2: lost serial"
      ;;

    ( --log-envnames )
        shift
        : "$(tr $'\n' ' ' < <(compgen -A variable "${IGNORE_VARS[@]}" ))"
        logger -p user.notice "$SUBSYSTEM ${ACTION-} event:${*:+ $*: }$_"
      ;;

    ( --log-generic-id )
        shift
        local v m="${DRIVER-} [e:$EUID u:$UID v:$UDEV_DATABASE_VERSION]"
        for v in $(compgen -A variable -X '!ID_*')
        do
          : "${!v}"
          m+=" $v=${_@Q}"
        done
        logger -p user.notice "$SUBSYSTEM $ACTION event:${*:+ $*:} $m"
      ;;

    ( --log-generic-model )
        shift
        : "$ID_MODEL $ID_MODEL_FROM_DATABASE ($ID_MODEL_ID) [b:$ID_BUS p:$ID_PATH t:$ID_TYPE ud:$ID_USB_DRIVER] [$ID_REVISION $ID_SERIAL]"
        logger -p user.notice "$SUBSYSTEM ${ACTION-} event:${*:+ $*:} $_"
      ;;

    ( --log-generic-usb )
        shift
        local v m="${DRIVER-} [${ID_PATH-} b:${ID_BUS-} t:${ID_TYPE-} m:${ID_MODEL-} r:${ID_REVISION-}] [e:$EUID u:$UID v:$UDEV_DATABASE_VERSION]"
        for v in $(compgen -A variable -X '!*USB*')
        do
          : "${!v}"
          m+=" $v=${_@Q}"
        done
        logger -p user.notice "$SUBSYSTEM $ACTION event:${*:+ $*:} $m"
      ;;

    ( --log-generic-usb-serial )
        shift
        local v m="${DRIVER-} [$DEVPATH] [e:$EUID u:$UID v:$UDEV_DATABASE_VERSION]"
        logger -p user.notice "$SUBSYSTEM $ACTION event:${*:+ $*:} $m"
      ;;

    * ) return ${_E_nsk:-67}
  esac
}

trigger ()
{
  case "${1:?}" in

    ( --found )
        command urxvt -title helper-udev-trigger \
          -hold -geometry 60x22+1020+550 \
          -e /srv/home-local/bin/usb.sh event --user-scan "${@:2}"
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
