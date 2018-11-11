#!/bin/sh


htd_darwin_disk_info()
{
  darwin_disk_info
}

htd_darwin_disk_stats()
{
  htd_disk_stats
  darwin_mount_stats
}

htd_darwin_disk_mounts()
{
  darwin_mounts | cut -d ' ' -f 1
}

htd_darwin_bsd_mounts()
{
  darwin_profile_xml "SPStorageDataType"
  #darwin_bsd_mounts
}

htd_darwin_partition_table()
{
  darwin_mounts
}


htd_linux_disk_check()
{
  sudo blkid /dev/sd* | tr -d ':' | while read dev props
  do
    eval $props
    test -z "$PARTUUID" && {
      echo $dev no-PARTUUID
    } || {
      grep -sr "$PARTUUID" ~/htdocs/sysadmin/disks.rst || {
        echo $dev $PARTUUID
      }
      continue
    }
    test -n "$UUID" || {
      echo $dev no-UUID
      continue
    }
    grep -sr "$UUID" ~/htdocs/sysadmin/disks.rst && continue || {
      echo $dev $UUID
    }
  done
}

htd_linux_disk_partitions()
{
  tail -n +3 /proc/partitions | awk '{print $'$1'}'
}

htd_linux_disk_mounts()
{
  cat /proc/mounts | cut -d ' ' -f 2
}

htd_linux_disk_tab()
{
  sudo file -s /var/lib/docker/aufs
  tail -n +3 /proc/partitions | while read major minor blocks dev_node
  do
    echo $dev_node
    sudo file -s /dev/$dev_node
    grep '^/dev/'$dev_node /proc/mounts
  done
}

htd_disk_id()
{
  test -n "$1" || error "Disk expected" 1
  test -e "$1" || error "Disk path expected '$1'" 1
  disk_id "$1" || return $?
}

htd_disk_model()
{
  test -n "$1" || error "Disk expected" 1
  test -e "$1" || error "Disk path expected '$1'" 1
  disk_id "$1" || return $?
}

htd_disk_size()
{
  test -n "$1" || error "Disk expected" 1
  test -e "$1" || error "Disk path expected '$1'" 1
  disk_size "$1" || return $?
}

htd_disk_tabletype()
{
  test -n "$1" || error "Disk expected" 1
  test -e "$1" || error "Disk path expected '$1'" 1
  disk_tabletype "$1" || return $?
}


htd_disk_runtime()
{
  test -n "$1" || set -- disk0
  note "Getting disk0 runtime (days)..."
  disk_runtime "$@"
}

htd_disk_bootnumber()
{
  test -n "$1" || set -- disk0
  note "TODO: Getting disk0 bootnumber (days)..."
  disk_bootnumber "$@"
}

htd_disk_stats()
{
  test -n "$1" || set -- disk0
  eval local $(disk_smartctl_attrs "$1")
  note "$1: Total runtime: $Power_On_Hours ($Power_On_Hours_Raw)"
  note "$1: Boots: $Power_Cycle_Count ($Power_Cycle_Count_Raw)"
  note "$1: Improper shutdowns: $Power_Off_Retract_Count ($Power_Off_Retract_Count_Raw)"
  note "$1: Disk temperature: $Temperature_Celsius ($Temperature_Celsius_Raw)"
}
