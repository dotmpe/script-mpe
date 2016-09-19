#!/bin/sh



disk_fdisk_id()
{
  {
    sudo fdisk -l $1 || return $?
  } | grep Disk.identifier | sed 's/^Disk.identifier: //'
}

disk_id()
{
  case "$(uname)" in
    Linux )
        udevadm info --query=all --name=$1 | grep ID_SERIAL_SHORT \
          | cut -d '=' -f 2
      ;;
    Darwin )
        # FIXME: this only works with one disk, would need to parse XML plist
        local b=$(basename $1)
        system_profiler SPSerialATADataType | grep -qv $b || {
          error "Parse SPSerialATADataType plist" 1
        }
        echo $(system_profiler SPSerialATADataType | grep Serial.Number \
          | cut -d ':' -f 2)
      ;;
  esac
}

disk_model()
{
  case "$(uname)" in
    Linux )
        {
          sudo parted -s $1 print || return $?
        } | grep Model: | sed 's/^Model: //'
      ;;
    Darwin )
        # FIXME: this only works with one disk, would need to parse XML plist
        system_profiler SPSerialATADataType | grep -qv disk1 || {
          error "Parse SPSerialATADataType plist" 1
        }
        echo $(system_profiler SPSerialATADataType | head -n 15  | grep Model \
          | cut -d ':' -f 2)
      ;;
  esac
}

disk_size()
{
  case "$(uname)" in
    Linux )
        {
          sudo parted -s $1 print || return $?
        } | grep Disk.*: | sed 's/^Disk[^:]*: //'
      ;;
    Darwin )
        echo $(system_profiler SPSerialATADataType | head -n 15 | grep Capacity \
          | cut -d ':' -f 2 | cut -d ' ' -f 2 )GB
      ;;
  esac
}

disk_tabletype()
{
  case "$(uname)" in
    Linux )
        {
          sudo parted -s $1 print || return $?
        } | grep Partition.Table: | sed 's/^Partition.Table: //'
      ;;
    Darwin )
        system_profiler SPSerialATADataType | grep -qv GPT || {
          error "Parse SPSerialATADataType plist" 1
        }
        echo gpt
      ;;
  esac
}

disk_local_inner()
{
  while test -n "$1"
  do
    case $(str_lower $1) in
      num ) disk_info $disk disk_index ;;
      dev ) printf -- "$disk " ;;
      disk_id ) disk_id $disk ;;
      disk_model ) disk_model $disk | tr ' ' '-';;
      size ) disk_size $disk ;;
      table_type ) disk_tabletype $disk ;;
      mnt_c ) find_mount $disk | count_words ;;
    esac
    shift
  done
}

# Print tab for lcal disk
#NUM DISK_ID DISK_MODEL SIZE TABLE_TYPE MOUNT_CNT
disk_local()
{
  local disk=$1; shift
  echo "$(disk_local_inner "$@")"

  return

  echo $first $(disk_id $1) $(disk_model $1 | tr ' ' '-') $(disk_size $1) \
    $(disk_tabletype $1) $(find_mount $1 | count_words)

}

# List local online disks (mounted or not)
disk_list()
{
  case "$(uname)" in
    Linux )
        glob=/dev/sd*[a-z]
        test "$(echo $glob)" = "$glob" || {
          echo $glob | tr ' ' '\n'
        }
      ;;
    Darwin )
        # FIXME: deal with system_profiler plist datatypes
        echo /dev/disk[0-9] \
          | tr ' ' '\n'
      ;;
  esac
}


# List all local disk partitions
disk_list_part_local()
{
  local glob=
  #test -n "$1" || error no-disk-list-part-local-args 1
  test -z "$2" || error surpluss-disk-list-part-args 1
  case "$(uname)" in
    Linux )
        test -z "$1" && glob=/dev/sd*[a-z]*[0-9] \
          || glob=$1[0-9]
      ;;
    Darwin )
        # FIXME: deal with system_profiler plist datatypes
        # This only uses first disk to avoid complexity
        test -z "$1" && glob=/dev/disk0s*[0-9] \
          || glob=$1[0-9]
      ;;
  esac

  test "$(echo $glob)" = "$glob" || {
    echo $glob | tr ' ' '\n'
  }
}

disk_partition_type()
{
  test -z "$1" || local dev=$1
  sudo blkid -o value -s TYPE $dev \
    || return $?
  # Or parse sudo file -Ls $dev
}

disk_partition_usage()
{
  dftabline=$(df -P $1 | tail -1);
  echo $(echo $dftabline | cut -f5 -d\  | sed -e 's/\%//g')
}

disk_partition_size()
{
  dftabline=$(df -hP $1 | tail -1);
  echo $(echo $dftabline | cut -f2 -d\  | sed -e 's/\%//g')
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

# TODO: Get mount point for dev/disk-id
# Get mount point for device path
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


### Disk Catalog functions

disk_info()
{
  test -n "$2" || set -- "$1" "prefix"
  test -e "$DISK_CATALOG/disk/$1.sh" || {
    # Find ID for device if given iso. ID
    set -- $(disk_id $1) $2
  }
  test -e "$DISK_CATALOG/disk/$1.sh" \
    || error "No such known disk $1" 1
  . $DISK_CATALOG/disk/$1.sh
  eval echo \$$2
}

# volume id is "{disk-id}-{partition-index}"
disk_vol_info()
{
  test -n "$2" || set -- "$1" "id"
  #test -e "$DISK_CATALOG/volume/$1.sh" || {
  #  # Find ID for device if given iso. ID
  #  set -- $(disk_vol_id $1) $2
  #}
  test -e "$DISK_CATALOG/volume/$1.sh" \
    || error "No such known volume $1" 1
  . $DISK_CATALOG/volume/$1.sh
  eval echo \$volumes_main_$2
}

disk_catalog_put_disk()
{
  test -n "$disk_id" || error "disk-id not set" 1
  test -n "$volumes_main_id" || error "volumes-main-id not set" 1
  {
    echo host=\"$host\"
    echo disk_id=$volumes_main_disk_id
    echo disk_index=$volumes_main_disk_index
    test -n "$volumes" \
      && echo volumes=\"$volumes $volumes_main_id\" \
      || echo volumes=\"$volumes_main_id\"

  } > $DISK_CATALOG/disk/$disk_id.sh
}

disk_catalog_update_disk()
{
  test "$disk_id" = "$volumes_main_disk_id" || {
    note "$disk_id != $volumes_main_disk_id"
    error "disk-id mismatch '$1'" 1
  }

  test "$disk_index" = "$volumes_main_disk_index" \
    || error "disk-index mismatch '$1'" 1

  info "Current host: '$host'"
  info "Existing volumes: '$volumes'"

  local update=
  fnmatch *"$volumes_main_id"* "$volumes" || update=1
  test "$(hostname)" = "$host" || update=1

  test -z "$update" ||  {
    disk_catalog_put_disk || return $?
  }
}

# Check .volumes.sh schema for disk
disk_catalog_volumes_check()
{
  test -n "$volumes_main_id" || error "Volumes doc '$1' missing id" 1
  test -n "$volumes_main_part_id" \
    || error "Volumes doc '$1' missing part_id" 1
  test -n "$volumes_main_part_index" \
    || error "Volumes doc '$1' missing part_index" 1
  test -n "$volumes_main_disk_id" \
    || error "Volumes doc '$1' missing disk_id" 1
  test -n "$volumes_main_disk_index" \
    || error "Volumes doc '$1' missing disk_index" 1
}

disk_catalog_update()
{
  test -n "$1" || error "disk-catalog-update volumes-sh expected" 1
  #eval $(sed 's/volumes_main_//g' $1)
  #test -n "$id" || error "Volumes doc '$1' missing id" 1
  host="$(hostname)"
  volumes_main_id= volumes_main_part_id= volumes_main_part_index=

  eval $(cat $1)
  disk_catalog_volumes_check "$1"

  test "$disk_id" = "$volumes_main_disk_id" || {
    warn "Please fix ID $disk_id != $volumes_main_disk_id ($1)" 1
    return
  }

  # Extract disk ID parts from volumes doc
  test -e "$DISK_CATALOG/disk/$disk_id.sh" \
    && {

      . "$DISK_CATALOG/disk/$disk_id.sh"
      disk_catalog_update_disk "$1"

    } || {

      test "$disk_id" = "$volumes_main_disk_id" \
        || error "disk-id mismatch '$1'" 1

      disk_catalog_put_disk
    }

}

disk_catalog_update_volume()
{
  test -e "$DISK_CATALOG/volume/$disk_id-$volumes_main_part_index.sh" \
    && {
      part_id="$volumes_main_part_id"
      . $DISK_CATALOG/volume/$disk_id-$volumes_main_part_index.sh
      test "$volumes_main_part_id" = "$part_id" || {
        warn "Partition changed: $volumes_main_part_id"
      }
    } || {
      cp $1 $DISK_CATALOG/volume/$disk_id-$volumes_main_part_index.sh
    }
}

# evaluate, and use update env to copy file
disk_catalog_import()
{
  test -e "$1" || {
    error "No metafile $1"
    return 1
  }
  test -n "$DISK_CATALOG" || error "DISK_CATALOG not set" 1
  (
    disk_catalog_update "$1" || return $?
    disk_catalog_update_volume "$1" || return $?
  )
  info "Imported '$1'"
}

