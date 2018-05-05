#!/bin/sh
# Created: 2017-02-25
srv__source=$_

set -e



version=0.0.4-dev # script-mpe


# Script subcmd's funcs and vars

# See '$scriptname help' to get started

srv_man_1__list="List all service volume instances"
srv__list()
{
  # Get service names and locations from DB, error if paths are missing
  noop
}
srv__global_status=list


srv_spc__list_raw='list-raw [GLOB [FMT]]'
srv__list_raw()
{
  noop
}


srv_man_1__info="Quick stats.."
srv__info()
{
  # Give info on service volume instance, or generic stats
  noop
}


srv_man_1__status="Semi quick stats.."
srv__status()
{
  # Recompile staging, by running update for our contexts w/o commit
  srv__update_services
  # Final comment on changes in staging
  noop
}


srv_man_1__info_raw="Update cache and give parsed details for local ..."
srv_spc__info_raw=" GREP [ FMT ] "
srv__info_raw()
{
  echo
}


srv_man_1__list_info="Update and list actual info about instances"
srv__list_info()
{
  echo
}
srv_als__details=list-info
srv_als__update=list-info


srv_man_1__update_services='Run both a check on the index and actual names found. '
srv__update_services()
{
  # Get service names and locations from DB and see wether paths exist and are
  # targetted correctly, or update
  noop
  # Walk over service names in FS roots, check wether they are tracked as
  # service or prepare an entry
  noop
  # Report on all services in staging, commit if required
  noop
}




# Generic subcmd's

srv_man_1__help="Usage help. "
srv_spc__help="-h|help"
srv__help()
{
  test -z "$dry_run" || stderr note " ** DRY-RUN ** " 0
  (
    base=srv \
      choice_global=1 std__help "$@"
  )
}
#srv_als__h=help
# FIXME:
#srv_als__help=help


srv_man_1__version="Version info"
srv__version()
{
  echo "script-mpe:$scriptname/$version"
}
#srv_als___V=version
#srv_als____version=version


srv__edit()
{
  $EDITOR $0 $(which $base.py) "$@"
}
srv_als___e=edit


# Script main functions

srv_main()
{
  local
      scriptname=srv \
      base=$(basename $0 .sh) \
      verbosity=5 \
      scriptpath="$(cd "$(dirname "$0")"; pwd -P)" \
      failed=

  srv_init || exit $?

  case "$base" in

    $scriptname )

        test -n "$1" || set -- list

        srv_lib || exit $?
        run_subcmd "$@" || exit $?
      ;;

    * )
        error "not a frontend for $base ($scriptname)" 1
      ;;

  esac
}

# FIXME: Pre-bootstrap init
srv_init()
{
  export LOG=/srv/project-local/mkdoc/usr/share/mkdoc/Core/log.sh

  test -n "$scriptpath"
  . $scriptpath/util.sh load-ext
  lib_load
  . $scriptpath/tools/sh/box.env.sh
  box_run_sh_test
  lib_load main meta box doc date table remote
  # -- srv box init sentinel --
}

# FIXME: 2nd boostrap init
srv_lib()
{
  local __load_lib=1
  # -- srv box lib sentinel --
  set --
}


### Subcmd init, deinit

# Pre-exec: post subcmd-boostrap init
srv_load()
{
  # -- srv box lib sentinel --
  set --
}

# Post-exec: subcmd and script deinit
srv_unload()
{
  local unload_ret=0

  #for x in $(try_value "${subcmd}" "" run | sed 's/./&\ /g')
  #do case "$x" in
  # ....
  #    f )
  #        clean_failed || unload_ret=1
  #      ;;
  #esac; done

  clean_failed || unload_ret=$?

  unset subcmd subcmd_pref \
          def_subcmd func_exists func \
          failed

  return $unload_ret
}


# Main entry - bootstrap script if requested
# Use hyphen to ignore source exec in login shell
case "$0" in "" ) ;; "-"* ) ;; * )

  # Ignore 'load-ext' sub-command
  test -z "$__load_lib" || set -- "load-ext"
  case "$1" in
    load-ext ) ;;
    * )
      srv_main "$@" ;;

  esac ;;
esac

# Id: script-mpe/0.0.4-dev srv.sh

