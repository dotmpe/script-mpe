#!/bin/sh

htd_man_1__disk='Enumerate disks '
htd__disk()
{
  lib_load disk htd-disk || return
  test -z "$(lib_path $os)" || lib_load $os || return
  test "$uname" = linux && {
    test -e /proc || error "/proc/* required" 1
  }
  test -n "${1-}" || set -- mounts
  subcmd_prefs=${base}_${os}_disk_\ ${base}_disk_\ disk_ try_subcmd_prefixes "$@"
}


htd__disks()
{
  test -n "$rst2xml" || error "rst2xml required" 1
  sudo which parted 1>/dev/null && parted=$(sudo which parted) \
    || warn "No parted" 1
  test -n "$parted" || error "parted required" 1

  DISKS=/dev/sd[a-e]
  for disk in $DISKS
  do
    echo "$disk $(htd disk-id $disk)"
    echo "  :table-type: $(htd disk-tabletype $disk)"
    echo "  :size: $(htd disk-size $disk)"
    echo "  :model: $(htd disk-model $disk)"
    echo ""
    for dp in $disk[0-9]*
    do
        pn="$(echo $dp | sed 's/^.*\([0-9]*\)/\1/')"
        ps="$(sudo parted $disk -s print | grep '^\ '$pn | awk '{print $4}')"
        pt="$(sudo parted $disk -s print | grep '^\ '$pn | awk '{print $5}')"
        fs="$(sudo parted $disk -s print | grep '^\ '$pn | awk '{print $6}')"
        echo "  - $dp $pt $(echo $(find_partition_ids $dp)) $ps $fs"
    done
    echo
  done
  echo
}

htd_man_1__disk_doc='
    list
    list-local
        See disk.sh

    update
        XXX: maybe see disk.sh about updating catalog
    sync
        Create/update JSON doc, with details of locally available disks.
    doc
        Generate JSON doc, with details of locally available disks.
'
htd_flags__disk_doc=f
htd__disk_doc()
{
  test -n "$1" || set -- list
  case "$1" in

      list|list-local ) disk.sh $1 || return $? ;;

      update ) ;;
      sync )  shift
           disk_list | while read dev
           do
             {
               disk_local "$dev" NUM DISK_ID || continue
             } | while read num disk_id
             do
               echo "disk_doc '$dev' $num '$disk_id'"
             done
           done
        ;;

      doc ) disk_doc "$@" || return $?
        ;;

  esac
}


htd__create_ram_disk()
{
  test -n "$1" || set -- "RAM disk" "$2"
  test -n "$2" || set -- "$1" 32
  test -z "$3" || error "Surplus arguments '$3'" 1

  note "Creating/updating RAM disk '$1' ($2 MB)"
  create_ram_disk "$1" "$2" || return
}


# XXX: host-disks hacky hacking one day, see wishlist above
list_host_disks()
{
  test -e sysadmin/$hostname.rst || error "Expected sysadm hostdoc" 1

  htd getx sysadmin/$hostname.rst \
    "//*/term[text()='Disk']/ancestor::definition_list_item/definition/definition_list" \
    > $sys_tmp/$hostname-disks.xml

  test -s "$sys_tmp/$hostname-disks.xml" || {
    rm "$sys_tmp/$hostname-disks.xml"
    return
  }

  {
    xsltproc - $sys_tmp/$hostname-disks.xml <<EOM
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
<xsl:template match="definition_list_item">
<xsl:value-of select="term"/> .
</xsl:template>
</xsl:stylesheet>
EOM
  # remove XML prolog:
  } | tail -n +2 | grep -Ev '^(#.*|\s*)$'
}

htd__check_disks()
{
  req_dir_env HTDIR
  cd $HTDIR
  list_host_disks | while read label path id eol
  do
    test -e "$path" && {
      echo "Path for $label OK"
      xmllint --xpath \
          "//definition_list/definition_list_item/definition/bullet_list/list_item[contains(paragraph,'"$path"')]/ancestor::bullet_list" \
          $sys_tmp/$hostname-disks.xml > $sys_tmp/$hostname-disk.xml;
      {
      xsltproc - $sys_tmp/$hostname-disk.xml <<EOM
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
<xsl:template match="//bullet_list/list_item">
<xsl:value-of select="paragraph/text()"/> .
</xsl:template>
</xsl:stylesheet>
EOM
  # remove XML prolog:
  } | tail -n +2 | grep -Ev '^(#.*|\s*)$' \
      || {
        warn "failed $?"
      }
    } || {
      error "Missing $label $id <$path>" 1
    }
  done
  rm $sys_tmp/$hostname-disk.xml
}


htd_disk_ids()
{
  true "${dev_pref:=sudo}"
  echo "# device, serial-id, fdisk-id, disk-model, disk-size"
  for dev in $(disk_list)
  do
      echo "$dev,$(disk_serial_id $dev),$(disk_fdisk_id $dev),$(disk_model $dev),$(disk_size $dev)"
  done
}

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

#htd_linux_disk_mounts()
#{
#  {
#    test $# -eq 0 && {
#      grep 'on\ ' /proc/mounts || return
#    } ||
#      grep 'on\ .*\ type\ \('"$(printf "%s\|" "$@")"'nosuchtype\)'
#    /proc/mounts || return
#  } |
#      sed 's/^.*\ on\ //g' | cut -d ' ' -f 1
#  #| cut -d ' ' -f 2
#}

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
  test -n "${1-}" || error "Disk expected" 1
  test -e "${1-}" || error "Disk path expected '$1'" 1
  disk_id "$1" || return $?
}

htd_disk_model()
{
  test -n "${1-}" || error "Disk expected" 1
  test -e "${1-}" || error "Disk path expected '$1'" 1
  disk_id "$1" || return $?
}

htd_disk_size()
{
  test -n "${1-}" || error "Disk expected" 1
  test -e "${1-}" || error "Disk path expected '$1'" 1
  disk_size "$1" || return $?
}

htd_disk_tabletype()
{
  test -n "${1-}" || error "Disk expected" 1
  test -e "$1" || error "Disk path expected '$1'" 1
  disk_tabletype "$1" || return $?
}

htd_disk_runtime()
{
  test -n "${1-}" || set -- sda
  test -x "$(which smartctl)" || smart_pref=sudo
  for dev in $@
  do test -e /dev/$1 || error "No such device '$1'" 1
    note "Getting '$dev' runtime..."
    echo "/dev/$dev:"; disk_runtime /dev/"$dev"; done
}

htd_disk_bootnumber()
{
  test -n "$1" || set -- sda
  test -x "$(which smartctl)" || smart_pref=sudo
  note "TODO: Getting disk0 bootnumber (days)..."
  for dev in $@
  do test -e /dev/$1 || error "No such device '$1'" 1
    note "Getting '$dev' bootnumber..."
    echo "/dev/$dev:"; disk_bootnumber /dev/"$dev"; done
}

htd_disk_stats()
{
  test -n "$1" || set -- sda
  test -x "$(which smartctl)" || smart_pref=sudo
  for dev in $@
  do test -e /dev/$1 || error "No such device '$1'" 1
  (
    eval local $(disk_smartctl_attrs /dev/"$dev")
    note "$dev: Total runtime: $Power_On_Hours ($Power_On_Hours_Raw)"
    note "$dev: Boots: $Power_Cycle_Count ($Power_Cycle_Count_Raw)"
    test -z "${Power_Off_Retract_Count-}" ||
      note "$1: Improper shutdowns: $Power_Off_Retract_Count ($Power_Off_Retract_Count_Raw)"
    note "$dev: Disk temperature: $Temperature_Celsius ($Temperature_Celsius_Raw)"
  )
  done
}
