#!/bin/sh
# Created: 2016-02-22
disk__source=$_

set -e

### User commands


disk__man_1_help="Usage help. "
disk_spc__help="-h|help"
disk_als___h=help
disk__help()
{
  test -z "$dry_run" || note " ** DRY-RUN ** " 0
  choice_global=1 std__help "$@"
}


disk__man_1_edit="Edit $base script file plus arguments. "
disk_spc__edit="-e|edit [<file>..]"
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


disk__status()
{
  disk__list_local | grep -Ev '^\s*(#.*|\s*)$' | while\
    read num dev disk_id disk_model size table_type
  do
    disk_id=$(printf "%-19s\n" $disk_id)
    test -e $dev || error "No such device? $dev" 1
    mnts="$(echo $(find_mount $dev))"
    stderr ok "${grey}[$disk_id] $num: $(echo $mnts | count_words) known partition(s) (${nrml}$size ${grey}$dev)"
    disk_list_part_local $dev | while read vol_dev
    do
      test -e "$vol_dev" || error "No such volume device '$vol_dev'" 1
      mount=$(find_mount $vol_dev)
      # FIXME: shomehow fstype is not showing up. Also, want part size/free 
      fstype="$(disk_partition_type "$vol_dev")"
      vol_idx=$(echo $vol_dev | sed -E 's/^.*([0-9]+)$/\1/')
      vol_id="$(disk_vol_info $disk_id-$vol_idx 2>/dev/null)"
      vsize=$(disk_partition_size $vol_dev)
      vusg=$(disk_partition_usage $vol_dev)
      case "$fstype" in
        swap* ) info "[$disk_id] $num.$vol_idx: swap space ($fstype $vol_dev)" ;;
        * )
          test -n "$mount" \
            && {
              info "[$disk_id] ${grn}$num.$vol_idx${grey}: ${bnrml}$vol_id${grey} ($vsize ${bnrml}$vusg%% ${grey}$fstype $vol_dev)"
              test -e $mount/.volumes.sh \
                || warn "Missing catalog at $mount"
            } || {
              fnmatch "* extended partition table *" " $(sudo file -sL $vol_dev) " && {
                info "[$disk_id] $num.$vol_idx: extended table ($fstype $vol_dev)"
              } || info "[$disk_id] ${ylw}$num.$vol_idx${grey} (unmounted or unrecognized: $fstype $vol_dev)"
            }
          ;;
      esac
    done
  done
}

disk__id()
{
  disk_id "$1"
}

disk__fdisk_id()
{
  disk_fdisk_id "$1"
}

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

disk__get_by_id()
{
  test "$(echo /dev/disk/by-id/*$1)" = "/dev/disk/by-id/*$1" \
    && return 1
  echo /dev/disk/by-id/*$1 | grep -v '\-part' | while read path
  do
    basename $path
  done
}

disk__prefix()
{
  test -n "$1" || error "disk expected" 1
  disk_info $1 prefix
}

# Get single attribute from catalog disk record by DISK_ID KEY
disk__info()
{
  disk_info "$@"
}


# Show disk info TODO: test this works at every platform
disk__local()
{
  test -n "$1" || set -- $(disk_list)
  {
    echo "#NUM DEV DISK_ID DISK_MODEL SIZE TABLE_TYPE MOUNT_CNT"
    {
      while test -n "$1"
      do
        disk_local "$1" NUM DEV DISK_ID DISK_MODEL SIZE TABLE_TYPE MNT_C
        shift
      done
    } | sort -n
  } | column -tc 3
}

disk__list_local()
{
  {
    echo "#NUM DEV DISK_ID DISK_MODEL SIZE TABLE_TYPE MOUNT_CNT"
    disk_list | while read disk
    do
      disk_local $disk NUM DEV DISK_ID DISK_MODEL SIZE TABLE_TYPE MNT_C \
        | grep -Ev '^\s*(#.*|\s*)$'
    done
  } | sort -n | column -tc 3
  echo "# Disks at $(hostname), $(datetime_iso)"
}
#disk__list_local()
#{
#  disk_list
#}
disk__list_part_local()
{
  disk_list_part_local
}

# Tabulate disks, and where they are (from catalog)
disk__list()
{
  {
    echo "#NUM DISK_ID HOST PREFIX"
    for disk in $DISK_CATALOG/disk/*.sh
    do

      . $disk

      # Find device and check
      dev=$(disk__get_by_id $disk_id)

      printf "$disk_index. $disk_id $host $prefix\n"
      unset host disk_id disk_index prefix volumes

    done
  } | sort -n | column -tc 3
  echo "# Catalog at $(hostname):$DISK_CATALOG, $(datetime_iso)"
}


disk__enable()
{
  note Done
}


disk__enable_volumes()
{
  note "TODO: enable volumes"
  note Done
}


disk__load_catalog()
{
  note "Loaded '$disk_id'"
}


disk__import_catalog()
{
  note "Imported '$disk_id' ($x volumes)"
}


disk__mount()
{
  note "Mounted '$1' at '$3'"
}


disk__mount_tmp()
{
  note "Mounted '$1' at temp '$3'"
}


disk__copy_fs()
{
  test -n "$1" || error "Device or disk-id required" 1
  test -n "$2" || error "Filename required" 1
  test -n "$3" || set -- "$1" "$2" "$(setup_tmpd)"
  test -z "$4" || error "surplus arguments '$4'" 1

  copy_fs "$1" "$2" "$3"
  note "Copied '$2' to '$3'"
}

# Return wether disk catalog looks up to date;
# ie. wether current catalog matches with available disks
disk__check()
{
  {
    disk__check_all \
      || return $?
  } > ~/.conf/disk/$hostname.txt
}

# FIXME: check only, see init/update
# Sort of wizard, check/init vol(s) interactively for current disks
disk__check_all()
{
  #note "Got r00t?"
  #sudo printf ""

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

disk__update_all()
{
  echo
}



### Subcmd init, deinit

disk_load()
{
  test -n "$uname" || uname=$(uname)
  test -n "$whoami" || whoami=$(whoami)
  test -n "$hostname" || hostname=$(hostname)
  test -n "$domainname" || domainname=$(domainname)

  test -n "$DISK_CATALOG" || export DISK_CATALOG=$HOME/.diskdoc
  #test -n "$DISK_VOL_DIR" || export DISK_VOL_DIR=/srv

  test -d "$DISK_CATALOG" || mkdir -p $DISK_CATALOG
  mkdir -p $DISK_CATALOG/disk
  mkdir -p $DISK_CATALOG/volume

  for x in $(try_value "${subcmd}" "" run | sed 's/./&\ /g')
  do case "$x" in

      f )
          failed=$(setup_tmpf .failed)
        ;;

    esac
  done

}

disk_unload()
{
  clean_failed
  unset subcmd_pref \
          def_subcmd func_exists func
}


### Main init, libs

disk_init()
{
  local __load_lib=1
  . $scriptdir/box.init.sh
  . $scriptdir/box.lib.sh
  box_run_sh_test
  . $scriptdir/main.lib.sh
  . $scriptdir/main.init.sh
  #while test $# -gt 0
  #do
  #  case "$1" in
  #      -v )
  #        verbosity=$(( $verbosity + 1 ))
  #        incr_c
  #        shift;;
  #  esac
  #done
  . $scriptdir/disk.lib.sh "$@"
  . $scriptdir/date.lib.sh
  . $scriptdir/match.lib.sh
  . $scriptdir/vc.sh load-ext
  test -n "$verbosity" || verbosity=6
  # -- disk box init sentinel --
}

disk_lib()
{
  local __load_lib=1
  . ~/bin/util.sh
  . ~/bin/box.lib.sh
  # -- disk box lib sentinel --
}


### Main

disk_main()
{
  local scriptname=disk base=$(basename $0 .sh) \
    subcmd=$1 scriptdir="$(cd "$(dirname "$0")"; pwd -P)"

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

				export SCRIPTPATH=$scriptdir
        . $scriptdir/util.sh
        util_init
        disk_init "$@" || error "init failed" $?
        shift $c

        disk_lib || exit $?
        run_subcmd "$@" || exit $?
      ;;

    * )
      echo "Not a frontend for $base ($scriptname)"
      exit 1
      ;;

  esac
}

case "$0" in "" ) ;; "-*" ) ;; * )

  # Ignore 'load-ext' sub-command
  # XXX arguments to source are working on Darwin 10.8.5, not Linux?
  # fix using another mechanism:
  test -z "$__load_lib" || set -- "load-ext"
  case "$1" in load-ext ) ;; * )

      disk_main "$@"
    ;;

  esac ;;
esac


