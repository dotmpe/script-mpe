#!/bin/sh
# Created: 2016-02-22
disk__source=$_

set -e

### User commands


disk__edit()
{
  $EDITOR \
    $0 \
    $(which disk.sh) \
    $(dirname $(which disk.sh)/disk.rst) \
    $(which diskdoc.sh) \
    $(which diskdoc.py) \
    "$@"
}


disk__status()
{
  note OK
}


disk__list()
{
  note End
}


disk__enable()
{
  note Done
}


disk__enable_volumes()
{
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
  note "Copied '$2' to '$3'"
}


# Sort of wizard, check/init vol(s) interactively for current disks
disk__check_all()
{
  test -d /dev/disk || error "Expected /dev/disk, e.g. Linux, not '$uname'" 1
  get_targets /dev/disk | while read dev
  do
    fnmatch "*[0-9]" "$dev" && {
      echo - $dev $(disk_partition_type $dev)
    } || {
      echo disk $dev $(disk_id $dev) $(disk_tabletype  $dev) 
    }
  done
}



### Subcmd init, deinit

disk_load()
{
  test -n "$uname" || uname=$(uname)
  test -n "$whoami" || whoami=$(whoami)
  test -n "$hostname" || hostname=$(hostname)
  test -n "$domainname" || domainname=$(domainname)

  #test -n "$DISK_VOL_DIR" || export DISK_VOL_DIR=/srv


  for x in $(try_value "${subcmd}" "" run | sed 's/./&\ /g')
  do case "$x" in

      f )
          failed=$(setup_tmp .failed)
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
  . $scriptdir/main.sh
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
  . $scriptdir/disk.inc.sh "$@"
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


