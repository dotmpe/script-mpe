#!/bin/sh

# disk device query routines


disk_lib_load()
{
  test -n "${uname-}" || uname="$(uname -s | tr '[:upper:]' '[:lower:]')"
  test -n "${username-}" || username="$(whoami | tr -dc 'A-Za-z0-9_-')"
  test -n "${hostname-}" || hostname="$(hostname -s | tr '[:upper:]' '[:lower:]')"

  test -n "${DISK_CATALOG-}" || DISK_CATALOG=$HOME/.diskdoc
}

disk_lib_init()
{
  test "${disk_lib_init-}" = "0" && return
  local log=; req_init_log

  test -d "$DISK_CATALOG" || mkdir -p $DISK_CATALOG
  mkdir -p $DISK_CATALOG/disk
  mkdir -p $DISK_CATALOG/volume

  mnt_pref="sudo " dev_pref=
  case "$(groups)" in
    *" disk "* ) ;;
    * )
      $log warn "" "No disk access, using sudo to read disk device info"
      # FIXME warn "No disk access, using sudo to read disk device info"
      dev_pref="sudo" ;;
  esac

  $log info "" "Loaded disk.lib" "$0"
}


req_fdisk()
{
  #test -n "${fdisk-}" -a -x "$($dev_pref which fdisk)" || {
  #  error "$1: missing fdisk" 1
  #}
  fdisk="$dev_pref $($dev_pref which fdisk)"
}

req_parted()
{
  #test -n "${parted-}" -a -x "$($dev_pref which parted)" || {
  #  error "$1: missing parted" 1
  #}
  parted="$dev_pref $($dev_pref which parted)"
}

req_blkid()
{
  #test -n "${blkid-}" -a -x "$($dev_pref which blkid)" || {
  #  error "$1: missing blkid" 1
  #}
  blkid="$dev_pref $($dev_pref which blkid)"
}


disk_fdisk_id()
{
  req_fdisk disk-fdisk-id || return
  case "$uname" in

      linux )
            { # List partition table
              $fdisk -l $1 || {
                error "disk-fdisk-id at '$1'"
                return $?
              }
            } | grep Disk.identifier | sed 's/^Disk.identifier: //'
          ;;

      darwin )
            # Dump partition table
              $fdisk -d $1 || return $?
          ;;

    * ) error "Disk-fdisk-Id: $uname" 1 ;;
  esac
}

disk_serial_id()
{
  case "$uname" in

    linux )
        udevadm info --query=all --name=$1 | grep ID_SERIAL_SHORT \
          | cut -d '=' -f 2
      ;;

    darwin )
        local bsd_name=$(basename $1) xml=
        #diskutil info "$1" | grep 'UUID' >&2 || warn "No grep $dev"

        xml=$(darwin_profile_xml "SPSerialATADataType")
        device_serial="$(darwin.py spserialata-disk $xml $bsd_name device_serial)" || true
        test -z "$device_serial" || {
          debug "SPSerialATADataType $bsd_name device serial '$device_serial'"
          echo $device_serial; return
        }

        xml=$(darwin_profile_xml "SPUSBDataType")
        serial_num="$(darwin.py spusb-disk $xml $bsd_name serial_num)" || true
        test -z "$serial_num" || {
          debug "SPUSBDataType $bsd_name serial number '$serial_num'"
          echo $serial_num; return
        }

        xml=$(darwin_profile_xml "SPStorageDataType")
        serial_num="$(darwin.py spstorage-disk $xml $bsd_name serial_num)" || true
        test -z "$serial_num" || {
          debug "SPStorageDataType $bsd_name serial number '$serial_num'"
          echo $serial_num; return
        }

        # Unfortunately need to dig trough volume group/mapping setup here.
        # Rather going to skip device ID and move to volumes directly.

        error "unkown disk $bsd_name" 1
      ;;

    * ) error "Disk-fdisk-Id: $uname" 1 ;;
  esac
}

disk_id() # DEVICE
{
  disk_serial_id "$@"
}

disk_id_for_dev()
{
  local dev="$1" ;
  local disk_id="$(disk_id "$dev")" || error "disk-id: '$dev'" 1
  test -z "$disk_id" && error "No disk Id for device '$dev'" 1
  std_info "Using Disk-ID '$disk_id' for '$dev'"
  echo "$disk_id"
}

disk_model()
{
  case "$uname" in

    linux ) req_parted disk-model || return

        req_parted disk-model || return
        {
          $parted -s $1 print || {
            error "disk-model at '$1'"
            return $?
          }
        } | grep Model: | sed 's/^Model: //'
      ;;

    darwin )
        # FIXME: this only works with one disk, would need to parse XML plist
        system_profiler SPSerialATADataType | grep -qv disk1 || {
          error "Parse SPSerialATADataType plist" 1
        }
        echo $(system_profiler SPSerialATADataType | head -n 15  | grep Model \
          | cut -d ':' -f 2)
      ;;

    * ) error "Disk-Model: $uname" 1 ;;
  esac
}

disk_size()
{
  case "$uname" in

    linux ) req_parted disk-size || return
        req_parted disk-size || return
        {
          $parted -s $1 print || {
            error "disk-size at '$1'"
            return $?
          }
        } | grep Disk.*: | sed 's/^Disk[^:]*: //'
      ;;

    darwin )
        echo $(system_profiler SPSerialATADataType | head -n 15 | grep Capacity \
          | cut -d ':' -f 2 | cut -d ' ' -f 2 )GB
      ;;

    * ) error "Disk-Size: $uname" 1 ;;
  esac
}

disk_tabletype()
{
  case "$uname" in

    linux ) req_parted disk-tabletype || return
        req_parted disk-tabletype || return
        {
          $parted -s $1 print || {
            error "disk-tabletype at '$1'"
            return $?
          }
        } | grep Partition.Table: | sed 's/^Partition.Table: //'
      ;;

    darwin )
        system_profiler SPSerialATADataType | grep -qv GPT || {
          error "Parse SPSerialATADataType plist" 1
        }
        echo gpt
      ;;

    * ) error "Disk-Tabletype: $uname" 1 ;;
  esac
}

disk_local_inner()
{
  local disk=$1; shift
  debug "disk-local-inner disk='$disk'"
  while test $# -gt 0
  do
    case $(str_lower $1) in
      num ) disk_info "$disk" disk_index || echo -1 ;;
      dev ) printf -- "$disk " || return $?;;
      disk_id ) disk_id $disk || return $?;;
      disk_model ) disk_model $disk | tr ' ' '-';;
      size ) disk_size $disk || return $?;;
      table_type ) disk_tabletype $disk || return $?;;
      mnt_c ) find_mount $disk | count_words ;;
      * ) error "inner $1?" 1 ;;
    esac
    shift
  done
}

# Print tab for lcal disk
#NUM DISK_ID DISK_MODEL SIZE TABLE_TYPE MOUNT_CNT
disk_local()
{
  test -n "$1" || error disk-local 1

  echo $( disk_local_inner "$@" || {
    #return 1
    echo "disk-local:$1:$2">>$failed
  } )

  test ! -e "$failed" -o ! -s "$failed" || return 1

  # XXX:
  #echo $first $(disk_id $1) $(disk_model $1 | tr ' ' '-') $(disk_size $1) \
  #  $(disk_tabletype $1) $(find_mount $1 | count_words)
}


disk_local_all()
{
  test -n "$*" || set -- $(os_disk_list)
  std_info "Devices: '$*'"
  {
    echo "#NUM DEV DISK_ID DISK_MODEL SIZE TABLE_TYPE MOUNT_CNT"
    {
      while test $# -gt 0
      do
        disk_local "$1" NUM DEV DISK_ID DISK_MODEL SIZE TABLE_TYPE MNT_C ||
          echo "disk:local:$1" >&2 # >$failed
        shift
      done
    } | sort -n
  } | column -tc 3
}


# List (local) disks by mount point
disk_mounts() # [TYPES]
{
  test $# -gt 0 || set -- vfat ntfs ext2 ext3 ext4
  case "$uname" in

    darwin | linux )
        mount | {
          test $# -eq 0 && {
            grep 'on\ ' || return
          } ||
            grep 'on\ .*\ type\ \('"$(printf "%s\|" "$@")"'nosuchtype\)'
        } |
            sed 's/^.*\ on\ //g' | cut -d ' ' -f 1
      ;;

    * ) error "Disk-Mounts not supported on: $uname" 1 ;;
  esac
}

# List (local) disks (from /dev, mounted or not)
os_disk_list()
{
  case "$uname" in

    linux )
        glob=/dev/sd*[a-z]
        test "$(echo $glob)" = "$glob" || {
          echo $glob | tr ' ' '\n'
        }
      ;;

    darwin )
        echo /dev/disk[0-9]* |
            tr ' ' '\n' |
            grep -v '[0-9]s[0-9]*$'
      ;;

    * ) error "Disk-List: $uname" 1 ;;
  esac
}

# List all local disk partitions
disk_list_part_local()
{
  local glob=
  test $# -gt 0 -a -n "${1-}" || error "Device or disk-id required" 1
  test $# -eq 1 || return 64
  case "$uname" in
    linux )
        test -z "$1" && glob=/dev/sd*[a-z]*[0-9] \
          || glob=$1[0-9]
      ;;
    darwin )
        # FIXME: deal with system_profiler plist datatypes
        # This only uses first disk to avoid complexity
        test -z "$1" && glob=/dev/disk0s*[0-9] \
          || glob=$1[0-9]
      ;;
    * ) error "Disk-List-Part-Local: $uname" 1 ;;
  esac

  test "$(echo $glob)" = "$glob" || {
    echo $glob | tr ' ' '\n'
  }
}

disk_partition_type()
{
  req_blkid disk-partition-type || return
  test -z "$1" || local dev=$1
  $blkid -o value -s TYPE $dev || return $?
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
  test -n "$2" || set -- "$1" 1
  tmpd=$(setup_tmpd disk/$2)
  warn "Mounting temporary disk $1"
  $mnt_pref mount $1 $tmpd || return $?
  note "Mounted $1 at $tmpd"
  tmp_mnt=$tmpd
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
  test $# -gt 0 -a -n "${1-}" || error "Device or disk-id required" 1
  test $# -eq 1 || return 64
  {
    # NOTE: docker adds a mount for the same device already mounted, first line ..
    mount | grep '^'$1 | head -n 1 | cut -d ' ' -f 3
  } || return $?
}

# Get device for mount point
get_device()
{
  test -n "$1" || error "Mount point argument expected" 1
  mountpoint "$1" >/dev/null || error "Mount point expected" 1
  test -z "$2" || error "surplus arguments '$2'" 1
  {
    mount | grep 'on\ '"$1" | cut -d ' ' -f 1
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
  test -n "${1-}" || error "disk-info disk-device" 1
  test -n "${2-}" || set -- "$1" "prefix"
  test -d "$DISK_CATALOG" || error "Invalid catalog env ($DISK_CATALOG)" 1

  test -e "$DISK_CATALOG/disk/$1.sh" || { {
      set -- "$(disk_id_for_dev "$1")" "$2" &&
      test -e "$DISK_CATALOG/disk/$1.sh"
    } || { error "No such known disk '$1'"; return 1; }; }

  . $DISK_CATALOG/disk/$1.sh
  eval echo \$$2
}

# volume id is "{disk-id}-{partition-index}"
disk_vol_info()
{
  test -d "$DISK_CATALOG" || error "Missing catalog env" 1
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
  test -d "$DISK_CATALOG" || error "Missing catalog env" 1
  test -n "$disk_id" || error "disk-id not set" 1
  test -n "$volumes_main_id" || error "volumes-main-id not set" 1
  {
    echo disk_host=\"$disk_host\"
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

  std_info "Current host: '$disk_host'"
  std_info "Existing volumes: '$disk_volumes'"

  local update=
  fnmatch *"$volumes_main_id"* "$disk_volumes" || update=1
  test "$(hostname)" = "$disk_host" || update=1

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
  test -d "$DISK_CATALOG" || error "Missing catalog env" 1
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
  test -d "$DISK_CATALOG" || error "Missing catalog env" 1
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
  test -d "$DISK_CATALOG" || error "Missing catalog env" 1
  (
    disk_catalog_update "$1" || return $?
    disk_catalog_update_volume "$1" || return $?
  )
  std_info "Imported '$1'"
}

disk_report()
{
  # leave disk_report_result to "highest" set value (where 1 is highest)
  disk_report_result=0

  while test $# -gt 0
  do
    case "$1" in

      unknown )     test $unknown_count -eq 0     || stderr warn "            Unkown: ${bdefault}$unknown_count${grey}  ($unknown_abbrev)" ;;
      uncataloged ) test $uncataloged_count -eq 0 || stderr warn "       Uncataloged: ${bdefault}$uncataloged_count${grey}  ($uncataloged_abbrev)" ;;

      ext )         test $ext_count -eq 0         || stderr info "         Extended tables: ${bdefault}$ext_count${grey}  ($ext_abbrev)" ;;
      swap )        test $swap_count -eq 0        || stderr info "                    Swap: ${bdefault}$swap_count${grey}  ($swap_abbrev)" ;;
      volume )      test $volume_count -eq 0      || stderr note "                 ${grn}Volumes: ${bdefault}$volume_count${grey}  ($volume_abbrev)" ;;
      disk )        test $disk_count -eq 0        || stderr note "             Disks total: ${bdefault}$disk_count${grey}  ($disk_abbrev)" ;;

      list )        test $list_count -eq 0        || stderr note "           Entries total: ${bdefault}$list_count${grey}"

        ;;

      * )
          error "Unknown disk report '$1'" 1
        ;;

    esac
    shift
  done

  return $disk_report_result
}

disk_doc()
{
{ cat <<EOM
host: $hostname

EOM
  } | jsotk yaml2json -
}

disk_smartctl_attrs()
{
  ${smart_pref} smartctl -A "$1" -f old | tail -n +8 | {
    local IFS=$' \t\n'
    while \
      read id attr flag value worst thresh type updated when_failed raw_value
    do
        test -n "$attr" || continue
        printf "%s " "$(printf "$attr" | tr -cs 'A-Za-z_' '_')_Raw=\"$raw_value\""
        printf "%s " "$(printf "$attr" | tr -cs 'A-Za-z_' '_')=\"$value\""
    done
  }
}

# Getting disk0 runtime (days)
disk_runtime () # DEV
{
  eval local $(disk_smartctl_attrs $1)
  #python -c "print $Power_On_Hours_Raw / 24.0"
  echo "$Power_On_Hours_Raw hours"
  echo "$(echo "$Power_On_Hours_Raw / 24" | bc) days"
  #echo "$Power_On_Hours"
}

disk_bootnumber () # DEV
{
  note "TODO: Getting disk0 boot count-crash count..."
  eval local $(disk_smartctl_attrs $1)
  test -z "${Power_Cycle_Count-}" ||
      echo "$Power_Cycle_Count-$Power_Cycle_Count_Raw"
  test -z "${Power_Off_Retract_Count-}" ||
      echo "$Power_Off_Retract_Count-$Power_Off_Retract_Count_Raw"
}

# Load into env or print on dry-run columns from lsblk output line
disk_lsblk_type_load() # Device Type Columns...
{
  local dev type lsblk colidx vid
  dev=$1 type=$2; shift 2
  lsblk="$(lsblk -o TYPE,$(echo $* | tr ' ' ',') $dev | grep -m 1 '^'$type' ' )" ||
      return
  for colidx in $(seq 2 $(( 1 + $# )) )
  do
    upper=1 mkvid $1
    test $# -gt 1 || colidx=$colidx- # Use all remaining fiels as value for last column
    trueish "${dry_run-}" &&
        echo "$vid=\"$(echo $lsblk | cut -d' ' -f$colidx)\"" ||
        eval "$vid=\"$(echo $lsblk | cut -d' ' -f$colidx)\""
    shift
  done
}

# Load into env columns from lsblk for disk devices
disk_lsblk_load() # Device Columns...
{
  local dev
  dev=$1 ; shift
  test $# -gt 0 || set -- KNAME TYPE TRAN RM SIZE SERIAL REV VENDOR MODEL
  disk_lsblk_type_load "$dev" disk "$@"
}

# Load into env columns from lsblk for partition devices
disk_partition_lsblk_load() # Device Columns...
{
  local dev
  dev=$1 ; shift
  disk_lsblk_type_load "$dev" part "$@"
}

# Print columns from lsblk for disk devices
disk_lsblk_show() # Device Columns
{
  dry_run=1 disk_lsblk_load "$@"
}
