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

event ()
{
  case "${1:?}" in

    ( --new-device )
      ;;

    ( --new-serial )
        shift
        #event --log-envnames $1
        #logger -p user.notice "$SUBSYSTEM ${ACTION-} event: /dev/$1: new UART $UART_PORT $UART_PRODUCT_ID $UART_SERIAL_ID"
        local var env
        for var in $(compgen -A variable -X '!UART*')
        do
          env+="$var=${!v-}"$'\n'
        done
        echo "$env" >| /run/user/${USB_UID:-1000}/uart-dev-$1.env
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

    ( --uart-found )
        local uart_env=/run/user/$UID/uart${2}.env
        while [[ ! -s $uart_env ]]
        do
          echo waiting for $uart_env
          sleep 5
        done
        . $uart_env
        #! (($#)) || eval "$*"
        echo found UART port ${UART_PORT-} vndid:${UART_VENDOR_ID-} prodid:${UART_PRODUCT_ID-} rev:${UART_REVISION_ID-} serno:${UART_SERIAL_ID-}
        #! (($#)) || echo "args: $*"
      ;;

  esac
}

info ()
{
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
