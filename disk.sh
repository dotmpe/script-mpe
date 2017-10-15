#!/bin/sh
# Created: 2016-02-22
disk__source=$_

set -e



version=0.0.4-dev # script-mpe


# Script subcmd's funcs and vars

# See $scriptname help to get started

disk_man_1__status="Print some information on currently mounted disks/partitions. "
disk__status()
{
  stderr info "Compiling status table on mounted volumes.."
  disk__list_local | grep -Ev '^\s*(#.*|\s*)$' | while\
    read num dev disk_id disk_model size table_type
  do
    disk_id_=$(printf "%-19s\n" $disk_id)
    num_=$(printf "%4s\n" $num)
    test -e $dev || error "No such device? $dev" 1
    echo "$dev" >>$disk
    mnts="$(echo $(find_mount $dev))"
    stderr ok "${grey}[$disk_id_] Disk #$num: $(echo $mnts | count_words) known partition(s) (${nrml}$size ${grey}$dev)"
    disk_list_part_local $dev | while read vol_dev
    do
      test -e "$vol_dev" || error "No such volume device '$vol_dev'" 1
      mount=$(find_mount $vol_dev)
      fstype="$(disk_partition_type "$vol_dev")"
      vol_idx=$(echo $vol_dev | sed -E 's/^.*([0-9]+)$/\1/')
      vol_id="$(disk_vol_info $disk_id-$vol_idx 2>/dev/null)"
      vsize=$(disk_partition_size $vol_dev)
      vusg=$(disk_partition_usage $vol_dev)
      case "$fstype" in
        swap* )
          info "[$disk_id_] $num_.$vol_idx: swap space ($vsize $vusg%% $fstype $vol_dev)"
          echo "$vol_dev" >>$swap
          echo "$num.$vol_idx: $vol_dev swap $vsize $vusg ($fstype) [$disk_id]" >>$list
          ;;
        * )
          test -n "$mount" \
            && {
              info "[$disk_id_] ${grn}$num_.$vol_idx${grey}: ${bnrml}$vol_id${grey} ($vsize ${bnrml}$vusg%% ${grey}$fstype $vol_dev)"
              test -e "$mount/.volumes.sh" && {
                echo "$vol_dev" >>$volume
                echo "$num.$vol_idx: $vol_id: $vol_dev $vsize $vusg ($fstype) [$disk_id]" >>$list
              } || {
                warn "Missing catalog at '$mount'"
                echo "$vol_dev" >>$uncataloged
              }
            } || {
              fnmatch "* extended partition table *" " $($dev_pref file -sL $vol_dev) " && {
                info "[$disk_id_] $num_.$vol_idx: extended table ($fstype $vol_dev)"
                echo "$vol_dev" >>$ext
                echo "$num.$vol_idx: $vol_dev extended table [$disk_id]" >>$list
              } || {
                info "[$disk_id_] ${ylw}$num_.$vol_idx${grey} (unmounted or unrecognized: $fstype $vol_dev)"
                echo "$vol_dev" >>$unknown
                echo "$num.$vol_idx: $vol_dev unrecognized ($vsize $fstype) [$disk_id]" >>$list
              }
            }
          ;;
      esac
    done
  done
  stderr info "Raw partition entries:"
  cat $list | sort -n
  rm $list
}
disk_load__status=Rfo
disk_outf__status="unknown uncataloged swap ext volume disk list"


disk_man_1__id="Print the disk ID of a given device or path. "
disk_spc__id="id [PATH|MOUNT|DEV]"
disk_load__id=R
disk__id()
{
  test -b "$1" || {
    test -d "$1" && {
      set -- "$(cd "$1"; pwd -P)"
    } || {
      error "Block device or directory expected"
    }

    # Set mount point
    set -- "$( df -P "$1" | awk 'END{print $NF}' )"
    note "Set mount point to '$1'"
  }

  test -b "$1" || {
    mountpoint "$1" >/dev/null || error "Mount point expected" 1

    # Set device
    set -- "$(get_device "$1")"
    note "Set device to '$1'"
  }

  disk_id "$1"
}

disk_man_1__fdisk_id="Print ID as reported by fdisk"
disk_spc__fdisk_id="fdisk-id DEV"
disk__fdisk_id()
{
  disk_fdisk_id "$1"
}

disk_man_1__rename_old="Rename fdisk catalog entry to one based on disk serial \
  number (Not good enough for some OEM SD cards)"
disk__rename_old()
{
  for disk in /dev/sd*[a-z]
  do
    disk_id=$(disk_id $disk)
    disk_full_id=$(disk__get_by_id $disk_id)
    old_disk_id=$(disk_fdisk_id $disk)
    mv -v $DISK_CATALOG/disk/$old_disk_id.sh $DISK_CATALOG/disk/$disk_id.sh
    (
      cd $DISK_CATALOG/volume/
      rename -v 's/^'"$old_disk_id"'/'"$disk_id"'/' $old_disk_id-*.sh
    )
  done
}

disk_man_1__get_by_id="Only on *nix/systems with /dev/disk tree."
disk__get_by_id()
{
  test "$(echo /dev/disk/by-id/*$1)" = "/dev/disk/by-id/*$1" \
    && return 1
  echo /dev/disk/by-id/*$1 | grep -v '\-part' | while read path
  do
    basename $path
  done
}


disk_man_1__prefix="Print disk mount name prefix. "
disk_spc__prefix="prefix DEV"
disk__prefix()
{
  test -n "$1" || error "disk expected" 1
  disk_info $1 prefix
}


disk_man_1__info="Get single attribute from catalog disk record by DISK_ID KEY"
disk__info()
{
  disk_info "$@"
}


disk_man_1__local="Show disk info TODO: test this works at every platform"
disk__local()
{
  test -n "$1" || set -- $(disk_list)
  {
    echo "#NUM DEV DISK_ID DISK_MODEL SIZE TABLE_TYPE MOUNT_CNT"
    {
      while test $# -gt 0
      do
        test -n "$1" || continue
        disk_local "$1" NUM DEV DISK_ID DISK_MODEL SIZE TABLE_TYPE MNT_C
        #\ || echo "disk:local:$1" >>$failed
        shift
      done
    } | sort -n
  } | column -tc 3
}
disk_load__local=f


disk_man_1__list_local="Tabulate disk info for local disks (e.g. from /dev/)"
disk_spc__list_local=list-local
disk__list_local()
{
  disk__local || return && echo "# Disks at $(hostname), $(datetime_iso)"
}
disk_load__list_local=f


disk__local_devices()
{
  disk_list
}


disk__x_local()
{
  darwin_disk_table
  return
  test -n "$1" || set -- $(disk_list)
  while test $# -gt 0
  do
    test -n "$1" || continue
    disk_local "$1" DISK_ID
    shift
  done
  return
  #disk_local "$1" NUM DEV DISK_ID DISK_MODEL SIZE TABLE_TYPE MNT_C
  for disk in $(disk_list)
  do
    system_profiler SPSerialATADataType | grep -q $(basename $disk)'\>' && {
      echo SerialATA disk=$disk
    } || {
      grep -q $(basename $disk)'\>' $darwin_disk_tab && {
        echo SPStorageDataType disk=$disk
      } ||
        stderr warn "Not in system-profiler db: $disk"
      continue
    }
  done
}
disk_load__x_local=f


disk_man_1__list_local_mounts='Print info for local partitions (using mount).
  Formats:
    list - only UUID each line
'
disk__list_local_mounts()
{
  local unknown_vols=$(setup_tmpf .unknown-vols)
  test -n "$out_fmt" || local out_fmt=list
  case "$out_fmt" in
    csv )
        echo '# Partition-Id, Disk-Index, Disk-Id, Partition-Index, Hostname, Mount-Point'
      ;;
  esac
  disk__list_mount_paths | while read mp
  do
    test -e $mp/.volumes.sh || {
      echo "$mp" >$unknown_vols
      warn "Unknown volume mounted at '$mp'"
      continue
    }
    (
      . $mp/.volumes.sh
      trueish "$choice_interactive" &&
        note "$volumes_main_part_id: $volumes_main_disk_index. ($volumes_main_disk_id) $volumes_main_part_index. at '$mp'"
      case "$out_fmt" in
        csv )
            echo "$volumes_main_part_id,$volumes_main_disk_index,$volumes_main_disk_id,$volumes_main_part_index,$hostname,$mp"
          ;;
        list )
            echo "$volumes_main_part_id"
          ;;
      esac
    )
  done
  test -s "$unknown_vols" -o -n "$choice_strict" || return 1
}


disk_man_1__list_mount_paths="List mounted paths (scanned from mount)"
disk__list_mount_paths()
{
  mount | grep '\ on\ ' | sed 's/.*\ on\ //g' | awk '{print $1}' | sort -u
}

disk_man_1__list_part_local="Print info for local partitions (from /dev/*)"
disk__list_part_local()
{
  disk_list_part_local "$@"
}

disk_man_1__list="Tabulate disks, and where they are (from catalog)"
disk__list()
{
  {
    echo "#NUM DISK_ID HOST PREFIX"
    for disk in $DISK_CATALOG/disk/*.sh
    do
      . $disk
      test -n "$disk_id" || {
        warn "Missing ID for <$disk> catalog entry <$prefix> '$description'"
        continue
      }

      # Find device and check
      dev=$(disk__get_by_id $disk_id)
      printf "$disk_index. $disk_id $host $prefix\n"
      unset host disk_id disk_index prefix volumes description
    done
  } | sort -n | column -tc 3
  echo "# Catalog at $(hostname):$DISK_CATALOG, $(datetime_iso)"
}


disk_man_1__enable="TODO"
disk__enable()
{
  note Done
}


disk_man_1__enable_volumes="TODO"
disk__enable_volumes()
{
  note "TODO: enable volumes"
  note Done
}


disk_man_1__load_catalog="TODO"
disk__load_catalog()
{
  note "Loaded '$disk_id'"
}


disk_man_1__import_catalog="TODO"
disk__import_catalog()
{
  note "Imported '$disk_id' ($x volumes)"
}


disk_man_1__mount="TODO"
disk__mount()
{
  note "Mounted '$1' at '$3'"
}


disk_man_1__mount_tmp="Temporarily mount given device. "
disk_spc__mount_tmp="mount-tmp DEV"
disk__mount_tmp()
{
  mount_tmp "$@"
}


disk_man_1__copy_fs="Temporarily mount FS, copy path, and unmount. "
disk__copy_fs()
{
  test -n "$1" || error "Device or disk-id required" 1
  test -n "$2" || error "Filename required" 1
  test -n "$3" || set -- "$1" "$2" "$(setup_tmpd)"
  test -z "$4" || error "surplus arguments '$4'" 1

  copy_fs "$1" "$2" "$3"
  note "Copied '$2' to '$3'"
}

disk_man_1__check="
Return wether disk catalog looks up to date;
ie. wether current catalog matches with available disks
"
disk__check()
{
  {
    disk__check_all \
      || return $?
  } > ~/.conf/disk/$hostname.txt
}

disk_man_1__check_all="
FIXME: check only, see init/update
Sort of wizard, check/init vol(s) interactively for current disks
"
disk__check_all()
{
  disk_list | while read dev
  do
    # Get disk meta

    disk_id=$(disk_id $dev)
    test "$disk_id" = "" && {
      error "Unknown type or unreadable partition table on disk '$dev'" 1
    } || {
      echo "$disk_id $dev $(disk_tabletype $dev) "

    }

    #}
    #  # Get partition meta

    #  fstype=$(disk_partition_type $dev)
    #  is_mounted $dev && {

    #    mount=$(find_mount $dev)
    #    disk_catalog_import $mount/.volumes.sh && {

    #      # Note: disk_id is set in preceeding look
    #      #. $DISK_CATALOG/$disk_id-.sh

    #      stderr ok "$mount ($fstype at $dev)"

    #    } || {

    #      stderr ok "$mount ($fstype at $dev)"
    #    }

    #  } || {

    #    # FIXME: get proper way of detecting supported fs types
    #    case "$fstype" in
    #      ext* | vfat | ntfs | iso9660 )
    #          note "TODO: $fstype copy_fs $dev '.package.{y*ml,sh}'"
    #        ;;
    #      '' | swap )
    #          info "Ignored partition $dev ($fstype)";;
    #      * )
    #          error "Unhandled fs type '$fstype'"
    #        ;;
    #    esac
    #  }

    #} || {

  done

  echo
}

disk_man_1__update_all="TODO: disk update-all"
disk__update_all()
{
  echo
}



# Generic subcmd's

disk_man_1__help="Usage help. "
disk_spc__help="-h|help"
disk_als___h=help
disk__help()
{
  test -z "$dry_run" || note " ** DRY-RUN ** " 0
  choice_global=1 std__help "$@"
}


disk_man_1__edit="Edit $base script file plus arguments. "
disk_spc__edit="-e|edit \[<file>..]"
disk__edit()
{
  $EDITOR \
    $0 \
    $(which disk.sh) \
    $(dirname $(which disk.sh))/disk.lib.sh \
    $(dirname $(which disk.sh))/disk.rst \
    $(which diskdoc.sh) \
    $(which diskdoc.py) \
    $(dirname $(which disk.sh))/test/disk-*.* \
    "$@"
}
disk_als___e=edit



# Script main functions

disk_main()
{
  local \
      scriptname=disk \
      base=$(basename $0 .sh) \
      scriptpath="$(cd "$(dirname "$0")"; pwd -P)" \
      subcmd=

  case "$base" in

    $scriptname )

        # invoke with function name first argument,
        local scsep=__ bgd= \
          subcmd_pref=${scriptalias} \
          disk_default=status \
          func_exists= \
          func= \
          sock= \
          c=0

				export SCRIPTPATH=$scriptpath
        . $scriptpath/util.sh
        util_init
        disk_init "$@" || error "init failed" $?
        shift $c

        disk_lib || exit $?
        run_subcmd "$@" || exit $?
      ;;

    * )
        echo "$scriptname: not a frontend for $base" >&2
        exit 1
      ;;

  esac
}

### Main init, libs

# FIXME: Pre-bootstrap init
disk_init()
{
  local __load_lib=1
  . $scriptpath/box.init.sh
  . $scriptpath/box.lib.sh
  box_run_sh_test
  lib_load main htd meta box date doc table disk darwin remote match
  test -n "$verbosity" || verbosity=6
  # -- disk box init sentinel --
}

# FIXME: 2nd boostrap init
disk_lib()
{
  local __load_lib=1
  . ~/bin/util.sh
  . ~/bin/box.lib.sh
  # -- disk box lib sentinel --
}


### Subcmd init, deinit

# Pre-exec: post subcmd-boostrap init
disk_load()
{
  disk_run
  #test -x "/sbin/parted" || error "parted required" 1
  #test -x "/sbin/fdisk" || error "fdisk required" 1
  test -n "$disk_session_id" || disk_session_id=$(get_uuid)
  disk__inputs="arguments options"
  disk__outputs="errored failed"

  test -n "$choice_interactive" || {
    # By default look at TERM
    test -z "$TERM" || {
      # may want to look at stdio t(ty) vs. f(ile) and p(ipe)
      # here we trigger by non-tty stderr
      test "$stdio_2_type" = "t" &&
        choice_interactive=1 || choice_interactive=0
      export choice_interactive
    }
  }

  for x in $(try_value "${subcmd}" load | sed 's/./&\ /g')
  do case "$x" in

    R ) # Device read access
        test -n "$dev_pref" || {
          ( for device in $(disk_list)
          do
            test -r "$device" && {
              stderr ok "Read/Write at $device"
            } || {
              exit 1
            }
          done
          ) || {
            export dev_pref="sudo"
            sudo echo >/dev/null || {
              note "Got r00t? (need sudo for /dev/* read-access)"
              sudo printf "Got it."
            }
          }
        }
      ;;

    f )
        failed=$(setup_tmpf .failed)
      ;;

    i ) # io-setup: set all requested io varnames with temp.paths
        setup_io_paths $subcmd-${disk_session_id}
        export $disk__inputs $disk__outputs
      ;;

    o ) #
        local subcmd_outf="$(eval echo "\$$(echo_local $subcmd outf)")"
        test -n "$subcmd_outf" || error "List of output names expected" 1
        disk__inputs= disk__outputs="$subcmd_outf" \
          setup_io_paths $subcmd-${disk_session_id}
        export $subcmd_outf
      ;;

    esac
  done
}

disk_unload()
{
  local unload_ret=0
  for x in $(try_value "${subcmd}" load | sed 's/./&\ /g')
  do case "$x" in

    i ) # remove named IO buffer files; set status vars
        clean_io_lists $disk__inputs $disk__outputs
        disk_report $disk__inputs $disk__outputs || subcmd_result=$?
      ;;

    o ) # idem. but for subcmd
        local subcmd_outf="$(eval echo "\$$(echo_local $subcmd outf)")"
        test -n "$subcmd_outf" || error "List of output names expected" 1
        clean_io_lists $subcmd_outf
        disk_report $subcmd_outf || subcmd_result=$?
      ;;

  esac; done
  clean_failed || unload_ret=1
  unset subcmd_pref \
          def_subcmd func_exists func
  return $unload_ret
}


# Main entry - bootstrap script if requested
case "$0" in "" ) ;; "-"* ) ;; * )

  # Ignore 'load-ext' sub-command
  # NOTE: arguments to source are working on Darwin 10.8.5, not Linux?
  # fix using another mechanism:
  test -z "$__load_lib" || set -- "load-ext"
  case "$1" in load-ext ) ;; * )
      disk_main "$@"
    ;;
  esac ;;
esac

# Id: script-mpe/0.0.4-dev disk.sh
