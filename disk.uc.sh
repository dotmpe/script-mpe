#!/usr/bin/env bash

# Start user-script early because we're using aliased script parts
test -n "${uc_lib_profile:-}" || . "${UCONF:?}/etc/profile.d/bash_fun.sh"
uc_script_load user-script


# XXX: setup aliases
! script_isrunning "disk.uc.sh" || {
  # Use alsdefs set to cut down on small multiline boilerplate bits.
  user_script_alsdefs \
    sa_a1_disk_dev l-argv1-bdev disk_dev "" \$lk ""
}


## Main handlers

disk_uc_add () # (u) ~
{
  local actdef=diskdoc lkn=add; sa_a1_act_lk
  case "$act" in
    ( dd|diskdoc )
        sa_a1_disk_dev
        disk_catalog_clrenv_disk || return
        diskdoc_load_disk_lsblk "$disk_dev" -- $disk_lsblk_keys_ext || {
          $LOG error "" "Unable to get device info" "" $?
          return
        }
        diskdoc_try_disk "$disk_dev" && {
          test -s "$disk_sh" && {
            $LOG warn "" "Found catalog entry" "$KNAME:$disk_id"
            return 1
          }
          $LOG notice "" "Missing disk-sh..."
        }
        declare -l -a vol_sh_files=()
        disks_uc for-disk-part disks_uc diskdoc-check-disk-volumes
        test ${#vol_sh_files[@]} -gt 0 && {
          first_volumesh=${vol_sh_files[0]}
          echo first: $first_volumesh
          grep '^volumes_main_' "$first_volumesh"
          eval "$(grep '^volumes_main_' "$first_volumesh")"
        } || {
          $LOG error "" "No volumes loaded from disk, no initial data"
        }
        disk_catalog_init_disk &&
          local key=disk_ name var val
          for name in $disk_keys_req
          do
            var=${key}${name//-/_}
            val=${!var:-}
            test -n "$val" && continue
            echo TODO: get $var:
          done
        disk_index=123
        disk_catalog_check_disk
      ;;

    ( * ) $LOG error "$lk" "No such action" "$act"; return 67 ;;
  esac
}

disk_uc_check () # ~
{
  local actdef=summary lkn=check; sa_a1_act_lk
  case "$act" in

    # ( D|diag ) rules_run user/rules ;;

    ( dd|doc|diskdoc ) disks_uc diskdoc-check ;;
    ( nt|numtab )      disks_uc numtab-check ;;
    ( nr|numbers )     disks_uc numbers-check ;;

    ( s|stat|summary )
        $ll Attn "disk.uc:check" "Checking disk device numbers.." &&
            disks_uc nums-chk && disks_uc ntab-chk &&
        $ll Attn "disk.uc:check" "Checking diskdoc Id's.."
            disks_uc ddoc-chk &&
        $ll Attn "disk.uc:check" "Checking volumes.sh's.."
            disks_uc v-chk &&
        $ll Attn "disk.uc:check" "Checking volume containers symlinks.."
            disks_uc srv-chk &&
        # TODO: use runner with LOG/pass-fail output
        $ll OK "disk.uc:check" "Local disks and config OK" ;;

    ( srv|volume-containers ) disks_uc volumes-containers-check ;;
    ( vols|volumes ) disks_uc volumes-check ;;

    ( v ) disks_uc v-chk-all && disks_uc srv-chk-all ;;

    ( * ) $LOG error "$lk" "No such action" "$act"; return 67 ;;
  esac
}


disk_uc_list () # ~
{
  local actdef=summary lkn=list; sa_a1_act_lk
  case "$act" in

    # ( D|diag|diag-rules ) rules_list user/diag ;;

    # Different ways of getting list of block/disk devices:
    ( disks-df ) disk_uc_list disks-df-info | tail -n +2 | cut -f1 -d' ' ;;
    ( disks-lsblk ) disk_lsblk_list "$@" ;;
    ( disks-devglob ) disk_list "$UC_DISK_DGLOB" ;;

    ( d|dev|devices|disks ) disks_uc list-devices "$@" ;;

    ( disks-df-info ) df -Th -x tmpfs -x devtmpfs -x squashfs ;;

    ( dd|doc ) disks_uc ddoc-media-ids ;;

    ( e|ext )
        fieldvars="$disk_lsblk_keys_ext"
        disks_uc table | column -s $'\t' -t ;;

    ( i|info ) disks_uc foreach disks_uc disk-info ;;

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
    ( nsi|numbers-ignore ) disk_devices_filter "!" "$@" ;;

    #( nsi|numbers-ignore ) disk_ignore_numbers "$@" ;;
    ( N|nums|drivers ) disks_uc disk-drivers ;;

    ( s|stat|summary )
        fieldvars="KNAME STATE TRAN HCTL RA RM RO VENDOR MODEL SERIAL SIZE"
        colvars="$fieldvars BSIZE"
        disks_uc table | column -s $'\t' -t ;;

    ( t|tree )
        disks_uc foreach-disk disks_uc tree-info
      ;;

    ( v|vol|vols|volumes ) # TODO: add diskdoc data
        disks_uc v-ls ;;

    ( * )
      test -b "$act" && {
        disk_partition_list "$act"
        return
      }
      $LOG error "$lk" "No such action" "$act"; return 67 ;;
  esac
}


disk_uc_status () # ~
{
  local actdef=summary; sa_a1_act_lk
  false
}

disks_uc ()
{
  local actdef=info; sa_a1_act_lk_2
  case "$act" in

    ( disk-info ) test $# -eq 0 || { local disk_dev=${1:?}; shift; }
        disks_uc disk-load
        echo "$disk_dev $SERIAL $KNUM $TRAN $MODEL $VENDOR $SIZE${RM_:+" removable"}"
        test ${v:-${verbosity:-4}} -lt 7 || disks_uc disk-dump
        #@smartctl disk_runtime "$disk_dev"
        #disk_serial_id "$disk_dev"
        $LOG notice "" "Found disk $disk_dev" "$KNAME:$VENDOR:$MODEL:$UUID"
      ;;
    ( disk-dump )
        for kn in $disk_lsblk_keys KNUM # KNUM_MAJOR KNUM_MINOR
        do echo "$kn: ${!kn}"
        done
      ;;
    ( disk-load|load ) diskdoc_load_disk "$disk_dev" ;;
    ( disk-load-lsblk|load-lsblk ) diskdoc_load_disk_lsblk "$disk_dev" ;;

    ( ddoc ) # List current user doc
        jsotk --pretty $USER_DISKS ;;
    ( ddoc-chk|diskdoc-check ) disks_uc for-disk disks_uc diskdoc-check-disk ;;
    ( ddoc-chk-dsk|diskdoc-check-disk )
        disks_uc disk-load-lsblk &&
        # Can filter-out devices with function per transport type
        ! sh_fun disk_uc_select_${TRAN}_device || {
            disk_uc_select_${TRAN}_device || {
              $LOG warn "" "Ignored ${TRAN^} device" "/dev/$KNAME:$VENDOR:$MODEL"
              return # $_E_continue
            }
          }
        local dev_pref=sudo disk_sh disk_id
        diskdoc_try_disk "$disk_dev" || return $_E_failure
        disks_uc_XXX_cleanup_diskdoc
        declare -l -a vol_sh_files=()
        disks_uc for-disk-part disks_uc diskdoc-check-disk-volumes
        test ${#vol_sh_files[@]} -gt 0 \
          && {
            test $v -lt 6 || {
              echo "Volumes on disk $disk_id at $disk_dev:" &&
                printf '\t%s\n' "${vol_sh_files[@]}"
            }
            diskdoc_check_volume_sh "$disk_id" "${vol_sh_files[@]}" || return
          } || $LOG warn "" "No mounted volumes from disk" "$disk_dev:$disk_id"

        test -s "$disk_sh" || {
          $LOG error "" "Missing shell file" "$disk_dev:$disk_id"
          return $_E_failure
        }
        . "$disk_sh"
      ;;
    ( ddoc-chk-dsk-vols|diskdoc-check-disk-volumes )
        disk_catalog_try_volume "$part_dev" || return
        vol_sh_files[${#vol_sh_files[@]}]=$vol_sh
      ;;
    ( ddoc-media-ids ) diskdoc_list_disks ;;

    ( for|for-disk|foreach|foreach-disk ) local failed=false disk_dev
        for disk_dev in $(disks_uc list-devices)
        do "$@" || {
          # XXX: fail early or test all; test $? -eq $_E_continue
          failed=true
        }
        done
        ! $failed || return
      ;;
    ( for-part|for-disk-part|foreach-disk-part ) local failed=false part_dev
        for part_dev in $(disks_uc list-partition-devices)
        do "$@" || failed=true
        done
        ! $failed || return
      ;;
    ( foreach-part|foreach-partition ) local failed=false part_dev
        for part_dev in $(disks_uc list-partitions-devices)
        do "$@" || failed=true
        done
        ! $failed || return
      ;;

    ( list-devices )
        #${UC_DISK_DEVICES:=disk_list} "$@"
        ${UC_DISK_DEVICES:-disk_lsblk_list} "$@" ;;

    ( list-partitions|list-partition-devices )
        disk_partition_list "$disk_dev" ;;
    ( list-partitions-devices )
        disks_uc foreach-disk disk_partition_list ;;

    ( ntab-chk|numtab-check )
        disk_devices_numbers | {
            local ok=true
            while read -r devmaj devname

### Htd/Catalog @Dev
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

    ( part-info ) test $# -eq 0 || { local part_dev=${1:?}; shift; }
        fieldvars="KNAME MOUNTPOINT SIZE UUID PTUUID PARTUUID FSTYPE LABEL"
        colvars=$fieldvars
        disk_partition_lsblk_load "$part_dev" $fieldvars
        vars_tabline - $colvars
        $LOG notice "" "Found partition $part_dev" "$KNAME:$MOUNTPOINT:$SIZE:$LABEL"
      ;;

    ( size-info ) test $# -eq 0 || { local disk_dev=${1:?}; shift; }
        lsblk_bsize=$(lsblk_opts=bdn disk_lsblk_field "$disk_dev" SIZE)
        lsblk_size=$(disk_lsblk_field "$disk_dev" SIZE)
        parted_size=$(disk_size "$disk_dev")
        $LOG notice "" "$disk_dev:$SERIAL " "$parted_size:$lsblk_size:$lsblk_bsize"
        #echo "Sectors: $fdisk_sectorcnt"

          #  echo "$part_dev $PTTYPE:${FSTYPE:-?} "
          #  #$(disk_partition_type "$disk_dev") $(disk_partition_usage "$disk_dev")"
          #  #disk_partition_size "$disk_dev"
      ;;

    ( srv-chk|volume-containers-check )
        lsblk_opts=b disk_partition_lsblk_load "$part_dev"
        $ll OK "disk.uc:srv:check" "" ;;

    ( srv-chk-all|volumes-containers-check )
        test -z "${disk_dev:-}" \
          && set -- foreach-part \
          || set -- for-disk-part
       disks_uc "$@" disks_uc volume-containers-check
      ;;

    ( tab|table )
        : "${fieldvars:=$disk_lsblk_keys}"
        : "${colvars:=$fieldvars}"
        echo "#${colvars// /,$'\t'}"
        disks_uc foreach-disk disks_uc tab-line-echo
      ;;

    ( tab-line-echo )
        diskdoc_load_disk_lsblk "$disk_dev" -- $fieldvars &&
        vars_tabline - $colvars
      ;;
    ( tab-line-part-echo )
        diskdoc_load_disk_lsblk "$part_dev" -- $fieldvars &&
        vars_tabline - $colvars
      ;;

    ( tree-info )
        disks_uc disk-info &&
        disks_uc for-part disks_uc part-info | sed 's/^/	/g'
      ;;

    ( v-l|vol-load|volume-load )
        diskdoc_load_partition "$part_dev"
      ;;
    ( v-ls|volumes-list )
        disks_uc foreach-part disks_uc volume-info
        # column -s $'\t' -tc 4
      ;;
    ( vi|v-info|vol-info|volume-info )
        disks_uc volume-load &&
        echo -e "$part_dev ${MOUNTPOINT:--}\t${FSTYPE:--} ${PTTYPE:--} $SIZE\t${UUID:-null}\t${PARTLABEL:--}"
      ;;

    ( v-chk-all|volumes-check )
        test -n "${disk_dev:-}" || {
          disks_uc for-disk disks_uc volumes-check
          return
        }
        disks_uc load && echo loaded &&
          env | grep '^disk_' && echo grepped &&
          disks_uc for-disk-part disks_uc volume-check
      ;;
    ( v-chk|volume-check )
        diskdoc_load_partition "$part_dev" &&
        $ll OK "disk.uc:vol:check" "" ;;

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

disks_uc_XXX_cleanup_diskdoc ()
{
  # XXX: cleanup; auto rename
  test -e "$DISK_CATALOG/disk/$SERIAL.sh" && {
    test -e "$disk_sh" && {
      echo "$disk_sh"
      $LOG error "" "Old and new file exist"
      return 1
    } || {
      $LOG error "" "Old file exist, copy?"
      mv "$DISK_CATALOG/disk/$SERIAL.sh" "$disk_sh"
    }
  }
}


vars_eecho () # ~ <Fs> <Default-> <Var-names...>
{
  test $# -ge 3 || return $_E_GAE
  local sep="${1:?}" def=${2:-} str v
  shift 2
  while test $# -gt 0
  do
    v=${!1:-$def}
    str="${str:-}${str:+$sep}$v"
    shift
  done
  echo -e "$str"
  return

  #using eval
  local shstr="\$${1:?}"
  shift
  while test $# -gt 0
  do
    shstr="$shstr\t\$$1"
  done
  eval "echo -e \"$shstr\""
}

vars_tabline () # ~ <Default-> <Var-names...>
{
  vars_eecho "\t" "$@"
}


## Main parts

disk_uc_defaults ()
{
  : "${USER_DISKS:=$UCONF/user/diskdoc.yml}"

  test -s "$USER_DISKS" || {
      $LOG error "" "Missing diskdoc" "$USER_DISKS"
      return 3
  }

  : "${UC_DISK_DGLOB:="\{nvme[0-9]n[1-9],sd[a-z]}"}"

  : "${ll:=$HOME/bin/log.sh}"

  { test -z "${iact:-}" && test -t 1 || trueish "$iact"
  } && iact=true || iact=false

  interactive=$($iact && echo 1 || echo 0)
}


## User-script parts


disk_uc_maincmds="status stat check list help version"
disk_uc_shortdescr=''

disk_uc_aliasargv ()
{
  case "$1" in
    ( a|add ) shift; set -- disk_uc_add diskdoc "$@" ;;
    ( c|chk|check ) shift; set -- disk_uc_check "$@" ;;
    ( l|ls|list ) shift; set -- disk_uc_list "$@" ;;
    ( t|tree ) shift; set -- disk_uc_list tree "$@" ;;
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
              args statusdir statusdir-fsdir \
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
          disk_uc_defaults
        ;;
    esac
    shift
  done
}

# Main entry (see user-script.sh for boilerplate)

! script_isrunning "disk.uc.sh" || {
  user_script_load || exit $?

  # Pre-parse arguments
  base=disk.uc
  script_defcmd=check
  user_script_defarg=defarg\ aliasargv

  eval "set -- $(user_script_defarg "$@")"

  script_run "$@"
}
