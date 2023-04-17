#!/usr/bin/env bash

set -euo pipefail
shopt -s nullglob

info ()
{
  for x in /sys/bus/usb/devices/${1:?}/
  do
    false
  done
}

list ()
{
  for usbnum in /sys/bus/usb/devices/usb[0-9]*/busnum
  do
    busnum=$(< "$usbnum")
    device=$(dirname "$usbnum")
    usbdev=$(< "$device/dev")
    usbver=$(< "$device/version")
    usbsp=$(< "$device/speed")
    test ! -e "$device/product" && usbprod= || usbprod=$(< "$device/product")
    echo "USB bus $busnum $usbprod (version $usbver, speed $usbsp, device $usbdev)"

    for usbnum2 in $device/*/busnum
    do
      device2=$(dirname "$usbnum2")
      bn=$(basename $device2)
      usbdev=$(< "$device2/dev")
      usbver=$(< "$device2/version")
      usbsp=$(< "$device2/speed")
      test ! -e "$device2/product" && usbprod= || usbprod=$(< "$device2/product")
      test -e /sys/bus/usb/drivers/usb/$bn && stat=" " || stat=" (offline)"
      echo "  $bn $usbdev $usbver $usbsp$stat $usbprod"
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
