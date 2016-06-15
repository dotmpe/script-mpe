#!/bin/sh



disk_id()
{
  sudo fdisk -l $1 | grep Disk.identifier\
      | sed 's/^Disk.identifier: //'
}

disk_model()
{
  sudo parted -s $1 print | grep Model: \
      | sed 's/^Model: //'
}

disk_size()
{
  sudo parted -s $1 print | grep Disk.*: \
      | sed 's/^Disk[^:]*: //'
}

disk_tabletype()
{
  sudo parted -s $1 print | grep Partition.Table: \
      | sed 's/^Partition.Table: //'
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

