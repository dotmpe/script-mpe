#!/usr/bin/env bash


check () # ~
{
  disks_uc check-doc
}


# lists disks and partitions based on major number dev drv name
disk_list_nonvirt_drv ()
{
  UC_VIRT_DEVS='loop ramdisk device-mapper'
  disk_drivers=$(disk_device_numbers|
      grep -v "$(grep_or_exact $UC_VIRT_DEVS)"|cut -f1 -d' ')

  for dev_drv in $disk_drivers
  do
    disk_list_by_nr $dev_drv
  done
}

status () # ~
{
  false
}


disks_uc ()
{
  local act=${1:-info}
  test $# -eq 0 || shift
  case "$act" in
    ( check-doc )
        dev_pref=sudo

        media_ids=$(jsotk keys $diskdoc -O lines catalog/media) || return

        for disk_dev in $(disk_list)
        do
          disks_uc disk-info "$disk_dev"
          test $RM -ne 0 || RM=
          echo "$disk_dev $SERIAL $KNUM $TRAN $MODEL $VENDOR $SIZE${RM:+" removable"}"
          echo "$media_ids" | grep "^$SIZE-" ||
              echo no record
          continue

          #disks_uc size-info "$disk_dev"
          #echo "Sectors: $fdisk_sectorcnt"
          #echo "Size: $fdisk_size $lsblk_size $parted_size $fdisk_bsize $lsblk_bsize "

          for part_dev in $(disk_list_part_local "$disk_dev")
          do
            disks_uc part-info "$part_dev"
            echo "$part_dev $PTTYPE:${FSTYPE:-?} "
            #$(disk_partition_type "$disk_dev") $(disk_partition_usage "$disk_dev")"
            #disk_partition_size "$disk_dev"
          done
        done
      ;;

    ( disk-info ) local disk_dev=${1:?}
        shift

        # parted report the same as lsblk
        # fdisk report the same as parted, but requires password

        #fdisk_hdrline=$(sudo fdisk -l $disk_dev | head -n 1)
        #fdisk_diskspec=$(echo "$fdisk_hdrline" | cut -d ':' -f2)
        #fdisk_size=$(echo "$fdisk_diskspec" | cut -d ',' -f 1 )
        #fdisk_bsize=$(echo "$fdisk_diskspec" | cut -d ',' -f 2 |
        #    tr -dc '[0-9]')
        #fdisk_sectorcnt=$(echo "$fdisk_diskspec" | cut -d ',' -f 3 |
        #    tr -dc '[0-9]')

        # Looks like PTUUID is set to PTUUID of first partition. PARTUUID is empty.
        eval "$(lsblk -bdnP "$disk_dev" -o "KNAME,SIZE,TRAN,RM,MODEL,VENDOR,SERIAL,UUID,PTTYPE")"
        KNUM=$(lsblk -dn "$disk_dev" -o MAJ:MIN)
        KNUM_MAJOR=${KNUM/:*}
        KNUM_MINOR=${KNUM/*:}
        $LOG notice "" "Found disk $disk_dev" "$KNAME:$VENDOR:$MODEL:$UUID"
      ;;

    ( part-info ) local part_dev=${1:?}
        shift
        eval "$(lsblk -bdnP "$part_dev" -o "KNAME,MOUNTPOINT,SIZE,UUID,PTUUID,PARTUUID,FSTYPE,LABEL")"
        $LOG notice "" "Found partition $disk_dev" "$KNAME:$MOUNTPOINT:$SIZE:$LABEL"
      ;;

    ( size-info ) local disk_dev=${1:?}
        shift
        lsblk_bsize=$(lsblk_opts=bdn disk_lsblk_field "$disk_dev" SIZE)
        lsblk_size=$(disk_lsblk_field "$disk_dev" SIZE)
        parted_size=$(disk_size "$disk_dev")
        $LOG notice "" "$disk_dev:$SERIAL " "$parted_size:$lsblk_size:$lsblk_bsize"
      ;;

    ( * ) ;;
  esac
}

disk_uc_list ()
{
  jsotk --pretty ~/.conf/disk/mpe.yaml
}


## User-script parts

disk_uc_maincmds="status stat check list help version"
disk_uc_shortdescr=''

disk_uc_aliasargv ()
{
  case "$1" in
      ( l|list ) shift; set -- disk_uc_list "$@" ;;
      ( "-?"|-h|h|help ) shift; set -- user_script_help "$@" ;;

  esac
}

disk_uc_loadenv ()
{
  test $# -gt 0 || set -- "$script_cmd"
  while test $# -gt 0
  do
    case "$1" in

      ( us-lib )
          . $U_S/tools/sh/init.sh || return
        ;;

      ( disk )
          { lib_require \
              argv statusdir statusdir-fsdir \
              date \
              disk disktab htd-disk
          } || return

            diskdoc=$UCONF/disk/mpe.yaml
            test -e "$diskdoc" || {
                $LOG error "" "Missing diskdoc" "$diskdoc"
                return 3
            }
        ;;

      #( all ) set -- "" nerdfonts media catalog ;;
      #( user_script_handlers ) set -- "" all ;;
      #( us_media ) set -- "$@" media ;;

      ( * ) set -- "" us-lib disk ;;
    esac
    shift
  done
}

# Main entry (see user-script.sh for boilerplate)

test -n "${user_script_loaded:-}" || {
  . "${US_BIN:="$HOME/bin"}"/user-script.sh &&
      user_script_shell_env
}

! script_isrunning "disk.uc.sh" || {
  # Pre-parse arguments
  base=disk.uc
  script_defcmd=check
  script_fun_xtra_defarg=disk_uc_aliasargv
  script_xtra_defarg=aliasargv

  eval "set -- $(user_script_defarg "$@")"
}

script_entry "disk.uc.sh" "$@"
