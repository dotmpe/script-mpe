#!/bin/sh

## Manage local disks at multiple hosts as tables in YAML

# catalog/mounts: last known volume locations

# catalog/media: table with all disks

# disks are complex records in catalog/media. volumes are recorded as part of
# disks.


diskdoc_lib_load ()
{
  : "${USER_DISKS:=$HOME/.local/etc/user/diskdoc.yml}"
}

diskdoc_lib_init ()
{
  test -s "${USER_DISKS:-}" || {
    $INIT_LOG error "" "User disks doc missing or empty" "${USER_DISKS:-null}"
  }
}


diskdoc_list_disks () # ~ [<Diskdoc.yaml>] # List Media Ids from document
{
  test $# -gt 0 || set -- "${USER_DISKS:?}"
  jsotk keys "$@" -O lines catalog/media || return
}

diskdoc_lsblk_disk ()
{
  lsblk_opts=db disk_lsblk_load "$1" || return
  test $RM -ne 0 || RM=
  KNUM=$(lsblk -dn "$1" -o MAJ:MIN)
  KNUM_MAJOR=${KNUM/:*}
  KNUM_MINOR=${KNUM/*:}
}

diskdoc_try_disk () # [dd-keys] ~ <Disk-dev> [<Diskdoc.yaml>]
{
  local disk_dev=${1:?}; shift; test $# -gt 0 || set -- "${USER_DISKS:?}"
  : "${dd_media_keys:=$( diskdoc_list_disks "$@" )}" || return

  { echo "$dd_media_keys" | grep -q "^$SIZE-$SERIAL" ||
    echo "$dd_media_keys" | grep -q "^$SIZE-" ||
    echo "$dd_media_keys" | grep -q "^$SERIAL"

  } && {
    $LOG notice "$lk:doc" "Found medium for device" "$KNAME:$TRAN:$VENDOR:$MODEL:$SERIAL"
    return 0
  } || {
    req_fdisk disk-fdisk-id || return
    FDISK_ID=$(disk_fdisk_id "$disk_dev")

    echo "$dd_media_keys" | grep -q "^$SERIAL" && {
      $LOG notice "$lk:doc" "Found old key for device" "$KNAME:$TRAN:$VENDOR:$MODEL:$SERIAL"
      return 0

    } || {
      $LOG error "$lk:doc" "No record for device" "$KNAME:$TRAN:$VENDOR:$MODEL:$SERIAL"
      echo $USER_DISKS catalog/medium/$SIZE-$FDISK_ID
      echo $USER_DISKS catalog/medium/$SERIAL
    }

    test -e ~/.conf/diskdoc/disk/$SERIAL.sh && {
      $LOG notice "$lk:cat" "Found shell catalog" "$KNAME:$TRAN:$VENDOR:$MODEL:$SERIAL"
      return 0

    } || {
      $LOG error "$lk:cat" "No shell catalog" "$KNAME:$TRAN:$VENDOR:$MODEL:$SERIAL"
      echo ~/.conf/diskdoc/disk/$SERIAL.sh
      return 1
    }
  }
}

diskdoc_autodetect () # ~ [<Pfile>] [<Diskdoc.yaml>]
{
  false
}

#
