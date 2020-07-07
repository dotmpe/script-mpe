#!/usr/bin/env make.sh
# Created: 2017-02-25

version=0.0.4-dev # script-mpe


# Script subcmd's funcs and vars

# See '$scriptname help' to get started

srv_man_1__list="List all service volume instances"
srv__list()
{
  # Get service names and locations from DB, error if paths are missing
  true
}
srv__global_status=list


srv_spc__list_raw='list-raw [GLOB [FMT]]'
srv__list_raw()
{
  true
}


srv_man_1__info="Quick stats.."
srv__info()
{
  # Give info on service volume instance, or generic stats
  true
}


srv_man_1__status="Semi quick stats.."
srv__status()
{
  # Recompile staging, by running update for our contexts w/o commit
  srv__update_services
  # Final comment on changes in staging
  true
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
  true
  # Walk over service names in FS roots, check wether they are tracked as
  # service or prepare an entry
  true
  # Report on all services in staging, commit if required
  true
}




# Generic subcmd's

srv_man_1__help="Usage help. "
srv_spc__help="-h|help"
srv__help()
{
  test -z "$dry_run" || stderr note " ** DRY-RUN ** " 0
  (
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


MAKE-HERE
INIT_ENV="init-log 0 0-src 0-u_s 0-1-lib-sys 0-std ucache scriptpath box"
INIT_LIB="\\\$default_lib main meta box doc date table remote std stdio"
main-local
failed=
main-init
main-lib
  local __load_lib=1
  INIT_LOG=$LOG lib_init || return
main-load
main-unload
  clean_failed || unload_ret=$?
  unset failed
main-epilogue
# Id: script-mpe/0.0.4-dev srv.sh
