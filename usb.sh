#!/usr/bin/env bash

set -euo pipefail
shopt -s nullglob

help ()
{
  echo "Commands:"
  sed 's/^/  /' < <( grep -Po '^[a-z_-]+(?= *\(\))' "$0")
  echo "Output:"
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
