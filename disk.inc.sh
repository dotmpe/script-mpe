#!/bin/sh



disk_id()
{
  {
    sudo fdisk -l $1 || return $?
  } | grep Disk.identifier | sed 's/^Disk.identifier: //'
}

disk_model()
{
  {
    sudo parted -s $1 print || return $?
  } | grep Model: | sed 's/^Model: //'
}

disk_size()
{
  {
    sudo parted -s $1 print || return $?
  } | grep Disk.*: | sed 's/^Disk[^:]*: //'
}

disk_tabletype()
{
  {
    sudo parted -s $1 print || return $?
  } | grep Partition.Table: | sed 's/^Partition.Table: //'
}

disk_partition_type()
{
  sudo blkid -o value -s TYPE $dev \
    || return $?
  # Or parse sudo file -Ls $dev
}

find_partition_ids()
{
  find /dev/disk/by-uuid -type l | while read path
  do
    test "$(basename $(readlink $path))" != "$(basename $1)" || {
      echo UUID:$(basename $path)
    }
  done

  if test -e /dev/disk/by-partuuid
  then
    find /dev/disk/by-partuuid -type l | while read path
    do
      test "$(basename $(readlink $path))" != "$(basename $1)" || {
        echo PART-UUID:$(basename $path)
      }
    done
  fi
}

# TODO handle disk-ids too

mount_tmp()
{
  test -n "$1" || error "Device or disk-id required" 1
  tmpd
  echo sudo mount $1 $tmpd || return $?
  note "Mounted $1 at $tmpd"
  export tmp_mnt=$tmpd
}

is_mounted()
{
  test -n "$1" || error "Device or disk-id required" 1
  test -z "$2" || error "surplus arguments '$2'" 1
  {
    mount | grep -q '^'$1
  } || return $?
}

find_mount()
{
  test -n "$1" || error "Device or disk-id required" 1
  test -z "$2" || error "surplus arguments '$2'" 1
  {
    mount | grep '^'$1 | cut -d ' ' -f 3
  } || return $?
}

copy_fs()
{
  test -n "$1" || error "Device or disk-id required" 1
  test -n "$2" || error "Filename required" 1
  test -n "$3" || set -- "$1" "$2" "/tmp"
  test -z "$4" || error "surplus arguments '$4'" 1

  mount_tmp $1 || set -- "$@" 11
  test -e $tmp_mnt/$2 $3 || set -- "$@" 12
  cp $tmp_mnt/$2 $3 || set -- "$@" 13
  umount $tmp_mnt || set -- "$@" 14
  rm -rf $tmp_mnt
  unset tmp_mnt

  test -n "$4" || set -- "$@" 0
  return $4
}

disk_catalog_import()
{
  test -e "$1" || {
    error "No metafile $1"
    return 1
  }
  echo 1: $1
}

