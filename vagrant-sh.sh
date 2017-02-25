#!/bin/sh
# Created: 2017-02-25
vagrant_sh__source=$_

set -e



version=0.0.3-dev # script-mpe


# Script subcmd's funcs and vars

# See $scriptname help to get started

vagrant_sh__list()
{
  stderr info "Listing running vagrant instances ($ vagrant global-status)"
  vagrant global-status | tail -n +3 |
  while read ID NAME PROVIDER STATE DIRECTORY
  do
    # NOTE: no warning on bugs, ignore non table lines
    test -d "$DIRECTORY" || continue
    $LOG header1 "$PROVIDER:$ID" "$NAME: $STATE " "$DIRECTORY"
  done
}


# Generic subcmd's

vagrant_sh_man_1__help="Usage help. "
vagrant_sh_spc__help="-h|help"
vagrant_sh__help()
{
  test -z "$dry_run" || note " ** DRY-RUN ** " 0
  choice_global=1 std__help "$@"
}
vagrant_sh_als___h=help


vagrant_sh_man_1__version="Version info"
vagrant_sh__version()
{
  echo "script-mpe:$scriptname/$version"
}
vagrant_sh_als__V=version


vagrant_sh__edit()
{
  $EDITOR $0 $(which $base.py) "$@"
}
vagrant_sh_als___e=edit





# Script main functions

vagrant_sh_main()
{
  local
      scriptname=vagrant-sh \
      base=$(basename $0 .sh) \
      verbosity=5 \
      scriptpath="$(cd "$(dirname "$0")"; pwd -P)" \
      failed=

  vagrant_sh_init || exit $?

  case "$base" in

    $scriptname )

        test -n "$1" || set -- list

        vagrant_sh_lib || exit $?
        run_subcmd "$@" || exit $?
      ;;

    * )
        error "not a frontend for $base ($scriptname)" 1
      ;;

  esac
}

# FIXME: Pre-bootstrap init
vagrant_sh_init()
{
  export LOG=/srv/project-local/mkdoc/usr/share/mkdoc/Core/log.sh

  test -n "$scriptpath"
  . $scriptpath/util.sh load-ext
  lib_load
  . $scriptpath/box.init.sh
  box_run_sh_test
  lib_load main meta box doc date table remote
  # -- vagrant-sh box init sentinel --
}

# FIXME: 2nd boostrap init
vagrant_sh_lib()
{
  local __load_lib=1
  # -- vagrant-sh box lib sentinel --
  set --
}


### Subcmd init, deinit

# Pre-exec: post subcmd-boostrap init
vagrant_sh_load()
{
  # -- vagrant-sh box lib sentinel --
  set --
}

# Post-exec: subcmd and script deinit
vagrant_sh_unload()
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

  env | grep -i 'vagrant'

  unset subcmd subcmd_pref \
          def_subcmd func_exists func \
          failed

  return $unload_ret
}



# Main entry - bootstrap script if requested
# Use hyphen to ignore source exec in login shell
case "$0" in "" ) ;; "-"* ) ;; * )

  # Ignore 'load-ext' sub-command
  case "$1" in
    load-ext ) ;;
    * )
      vagrant_sh_main "$@" ;;

  esac ;;
esac

# Id: script-mpe/0.0.3-dev vagrant-sh.sh
