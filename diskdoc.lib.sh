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


diskdoc_check_volume_sh () # ~ <Disk-id> <Volume-sh...>
{
  local disk_id=${1:?} ; shift
  # TODO return 1
}

diskdoc_list_disks () # ~ [<Diskdoc.yaml>] # List Media Ids from document
{
  test $# -gt 0 || set -- "${USER_DISKS:?}"
  jsotk keys "$@" -O lines catalog/media || return
}

diskdoc_load_disk () # ~ <Disk-dev>
{
  disk_id=
  diskdoc_load_disk_lsblk "${1:?}" &&
    diskdoc_try_disk "$1" && {
      test -e "$disk_sh" &&
        disk_catalog_load_disk "$disk_id"
      return
    } ||
      echo no catalog? $1 >&2
}

diskdoc_load_disk_lsblk () # ~ <Disk-device> [<Keyset>] # Load lsblk disk env (see disk-lsblk-load)
{
  local disk_dev=${1:?}; shift
  case "${1:-}" in
    ( ext ) set -- $disk_lsblk_keys_ext ;;
    ( "" ) set -- $disk_lsblk_keys ;;
    ( -- ) shift ;;
    ( * ) return $_E_GAE ;;
  esac
  unset SIZE BSIZE RM RO
  lsblk_opts=db disk_lsblk_load "$disk_dev" $@ || return
  BSIZE=${SIZE:?}
  lsblk_opts=d disk_lsblk_load "$disk_dev" SIZE || return
  test -z "${RM:-}" || RM_=$(test "$RM" -eq 0 || printf 1)
  test -z "${RO:-}" || RO_=$(test "$RO" -eq 0 || printf 1)
  KNUM=$(lsblk -dn "$disk_dev" -o MAJ:MIN)
  KNUM_MAJOR=${KNUM/:*}
  KNUM_MINOR=${KNUM/*:}
}

# TODO: check disk catalog entry and resolve issues while interactive
diskdoc_try_disk () # [dd-keys] ~ <Disk-dev> [<Diskdoc.yaml>]
{
  local disk_dev=${1:?}; shift; test $# -gt 0 || set -- "${USER_DISKS:?}"
  # Get list of known Ids from diskdoc
  : "${dd_media_keys:=$( diskdoc_list_disks "$@" )}" || return

  { echo "$dd_media_keys" | grep -q "^$BSIZE-$SERIAL$"
  } && {
    disk_id=$BSIZE-$SERIAL
    disk_sh=$DISK_CATALOG/disk/$disk_id.sh
    return
  }

  { echo "$dd_media_keys" | grep -q "^$SERIAL$"
  } && {
    disk_id=$SERIAL
    disk_sh=$DISK_CATALOG/disk/$disk_id.sh
    $LOG warn "" "Id from SERIAL is not in preferred formats" "$disk_id"
    return
  }

  { echo "$dd_media_keys" | grep -q "^$BSIZE-"
  } && {
    $LOG error "$lk:doc" "Potential medium match on size" "$KNAME:$TRAN:$VENDOR:$MODEL:$SERIAL"
    return 1
  } || {
    $iact || return 1

    req_fdisk disk-fdisk-id || return
    FDISK_ID=$(disk_fdisk_id "$disk_dev")

    echo "$dd_media_keys" | grep -q "^$SERIAL" && {
      $LOG notice "$lk:doc" "Found old key for device" "$KNAME:$TRAN:$VENDOR:$MODEL:$SERIAL"
      return 0

    } || {
      $LOG error "$lk:doc" "No record for device" "$KNAME:$TRAN:$VENDOR:$MODEL:$SERIAL"
      echo $USER_DISKS catalog/medium/$BSIZE-$SERIAL
    }

    test -e "$DISK_CATALOG/disk/$SERIAL.sh" && {
      $LOG notice "$lk:cat" "Found shell catalog" "$KNAME:$TRAN:$VENDOR:$MODEL:$SERIAL"
      return 0

    } || {
      $LOG error "$lk:cat" "No shell catalog" "$KNAME:$TRAN:$VENDOR:$MODEL:$SERIAL"
      echo "$DISK_CATALOG/disk/$SERIAL.sh"
      return 1
    }
  }
}

diskdoc_load_partition ()
{
  diskdoc_load_partition_lsblk "${1:?}" &&
  echo TODO: disk_catalog_load_partition
}

diskdoc_load_partition_lsblk ()
{
  local disk_dev=${1:?}; shift
  case "${1:-}" in
    #( ext ) set -- $disk_partition_lsblk_keys_ext ;;
    ( "" ) set -- $disk_partition_lsblk_keys ;;
    ( -- ) shift ;;
    ( * ) return $_E_GAE ;;
  esac
  unset SIZE BSIZE RM RO
  lsblk_opts=bd disk_partition_lsblk_load "$part_dev" || return
  BSIZE=${SIZE:?}
  lsblk_opts=d disk_lsblk_load "$disk_dev" SIZE || return
}

#
