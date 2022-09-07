#!/usr/bin/env bash


disk_uc_check () # ~
{
  local act=${1:-summary}
  local lk=${lk:-$base}:check
  test $# -eq 0 || shift
  case "$act" in

    # ( D|diag ) rules_run user/rules ;;

    ( doc )          disks_uc doc-check ;;
    ( nt|numtab )    disks_uc numtab-check ;;
    ( nr|numbers )   disks_uc numbers-check ;;

    ( s|stat|summary )
        $ll warn "disk.uc[$$]:check" "Checking disk device numbers.." &&
            disks_uc nums-chk && disks_uc ntab-chk &&
        $ll warn "disk.uc[$$]:check" "Checking diskdoc Id's.."
            disks_uc doc-chk &&
        # TODO: use runner with LOG/pass-fail output
        $ll ok "disk.uc[$$]:check" "Local disk device numbers and diskdoc Id's OK" ;;

    ( * ) $LOG error "$lk" "No such action" "$act"; return 67 ;;
  esac
}


disk_uc_list () # ~
{
  local act=${1:-summary}
  test $# -eq 0 || shift
  local lk=${lk:-$base}:list
  case "$act" in

    # ( D|diag|diag-rules ) rules_list user/diag ;;

    # Different ways of getting list of block/disk devices:
    ( disks-df ) disk_uc_list disks-df-info | tail -n +2 | cut -f1 -d' ' ;;
    ( disks-lsblk ) disk_lsblk_list "$@" ;; # $UC_DISK_DGLOB ;;
    ( disks-dev ) disk_list $UC_DISK_DGLOB ;;
    ( d|dev|devices|disks ) disk_uc_list disks-dev ;;

    ( disks-df-info ) df -Th -x tmpfs -x devtmpfs -x squashfs ;;

    ( doc ) disks_uc doc-media-ids ;;

    ( i|info )
        test $# -gt 0 || set -- $(${UC_DISK_DEVICES:=disk_lsblk_list})
        for disk_dev in "$@"
        do
          disks_uc disk-info "$disk_dev"

          disk_serial_id "$disk_dev"
          $LOG notice "" "Found disk $disk_dev" "$KNAME:$VENDOR:$MODEL:$UUID"
        done
      ;;

    ( nonvirt )
# Lists disks and partitions based on major number dev drv name
        disk_drivers=$(disk_device_numbers|
            grep -v "$(grep_or_exact $USER_VDISKDEVS)"|cut -f1 -d' ')

        for dev_drv in $disk_drivers
        do
          disk_list_by_nr $dev_drv
        done
      ;;

    ( nr|num|numbers ) disk_device_numbers "$@" ;;
    ( ns|numbers-all ) disk_devices_numbers ;;
    ( nsi|numbers-ignore ) disk_ignore_numbers "$@" ;;
    ( N|nums|drivers ) disks_uc disk-drivers ;;

    ( s|stat|summary )
        disk_uc_list info ;;

    ( * ) $LOG error "$lk" "No such action" "$act"; return 67 ;;
  esac
}


disk_uc_status () # ~
{
  false
}

disks_uc ()
{
  local act=${1:-info}
  test $# -eq 0 || shift
  local lk="${lk:-:$base:$act}"
  case "$act" in
    ( list-devices ) ${UC_DISK_DEVICES:=disk_list} "$@" ;;

    ( doc-chk|doc-check ) local failed=false dev_pref=sudo
        for disk_dev in $(disks_uc list-devices)
        do
          disks_uc disk-info "$disk_dev"
          ! sh_fun disk_uc_select_${TRAN}_device || {
              disk_uc_select_${TRAN}_device || {
                $LOG warn "" "Ignored SD-USB device" "$KNAME"
                continue
              }
            }
          diskdoc_try_disk "$disk_dev" || failed=true
        done
        ! $failed || return
      ;;

    ( disk-info ) local disk_dev=${1:?}
        shift
        diskdoc_lsblk_disk "$disk_dev"
        echo "$disk_dev $SERIAL $KNUM $TRAN $MODEL $VENDOR $SIZE${RM:+" removable"}"
        # TODO: dump but only on v=7
        $LOG notice "" "Found disk $disk_dev" "$KNAME:$VENDOR:$MODEL:$UUID"
      ;;

    ( disk-dump ) local disk_dev=${1:?}
        shift
        for kn in $disk_lsblk_keys KNUM KNUM_MAJOR KNUM_MINOR
        do
          echo "$kn: ${!kn}"
        done
      ;;
    ( doc )
# List current user doc
        jsotk --pretty $USER_DISKS ;;
    ( doc-media-ids ) diskdoc_list_disks ;;

    ( ntab-chk|numtab-check )
        disk_devices_numbers | {
            local ok=true
            while read -r devmaj devname
            do grep -q "^$devname " "$USER_DEVS" && continue
              ! $ok || ok=false
              echo Unkown device: $devmaj $devname >&2
            done
            $ok
          }
      ;;

    ( nums|disk-drivers )
        disk_devices_numbers | while read -r devmaj devname
        do
          grep "^$devname " "$USER_DEVS" || {
            $LOG error "" "Unknown device name" "$devmaj:$devname" $?
            return
          }
        done | remove_dupes
      ;;

    ( nums-chk|numbers-check ) local ok=true unknown_devnames
        unknown_devnames=$(
            disk_devices_filter "!" $USER_DISKDEVS $USER_VDISKDEVS) &&
          test -n "$unknown_devnames" || return 0
        echo "$unknown_devnames" | {
            while read -r devmaj devname
            do
              ! $ok || ok=false
              echo "Unkown device: $devmaj $devname" >&2
            done
            $ok
          }
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
          #continue

          #disks_uc size-info "$disk_dev"
          #echo "Sectors: $fdisk_sectorcnt"
          #echo "Size: $fdisk_size $lsblk_size $parted_size $fdisk_bsize $lsblk_bsize "

          #for part_dev in $(disk_list_part_local "$disk_dev")
          #do
          #  disks_uc part-info "$part_dev"
          #  echo "$part_dev $PTTYPE:${FSTYPE:-?} "
          #  #$(disk_partition_type "$disk_dev") $(disk_partition_usage "$disk_dev")"
          #  #disk_partition_size "$disk_dev"
          #done
      ;;

    ( * ) $LOG error "$lk" "No such action" "$act"; return 67 ;;
  esac
}

# For USB SD-card readers the firmware reports a fixed SERIAL that equals
# iSerial from lsusb output. The user can record devices to exclude them from
# disk certain functions and rules in USER_SDUSB
disk_uc_select_usb_device ()
{
  ! grep -q $'\t'"$SERIAL"$'\t' "$USER_SDUSB"
}


## Main parts

: "${USER_DISKS:=$UCONF/user/diskdoc.yml}"

test -s "$USER_DISKS" || {
    $LOG error "" "Missing diskdoc" "$USER_DISKS"
    return 3
}

: "${UC_DISK_DGLOB:=sd[a-z]}"


## User-script parts


disk_uc_maincmds="status stat check list help version"
disk_uc_shortdescr=''

disk_uc_aliasargv ()
{
  case "$1" in

      ( c|chk|check ) shift; set -- disk_uc_check "$@" ;;
      ( l|ls|list ) shift; set -- disk_uc_list "$@" ;;
      ( s|status ) shift; set -- disk_uc_status "$@" ;;
      ( S|stat ) shift; set -- disk_uc_stat "$@" ;;

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
              disk disktab diskdoc htd-disk
          } || return
        ;;

      ( rules )
          { lib_require \
              env-main rules
          } || return
        ;;

      #( user_script_handlers ) set -- "" all ;;
      #( us_media ) set -- "$@" media ;;

      ( * ) set -- "" us-lib disk rules
          ll=$HOME/bin/log.sh ;;
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
