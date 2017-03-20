#!/bin/sh

topics_src=$_
test -z "$__load_lib" || set -- "load-ext"

set -e



version=0.0.3-dev # script-mpe


# Script subcmd's funcs and vars

# See $scriptname help to get started

topics__list()
{
  echo TODO: topics list
}




# Generic subcmd's

topics_man_1__help="Usage help. "
topics_spc__help="-h|help"
topics__help()
{
  test -z "$dry_run" || note " ** DRY-RUN ** " 0
  choice_global=1 std__help "$@"
}
topics_als___h=help


topics_man_1__version="Version info"
topics__version()
{
  echo "script-mpe:$scriptname/$version"
}
topics_als__V=version


topics__edit()
{
  $EDITOR $0 $(which $base.py) "$@"
}
topics_als___e=edit




# Script main functions

topics_main()
{
  local
      scriptname=topics \
      base=$(basename $0 .sh) \
      verbosity=5 \
    scriptpath="$(cd "$(dirname "$0")"; pwd -P)" \
    failed=

  topics_init || exit $?

  case "$base" in

    $scriptname )

        test -n "$1" || set -- list

        topics_lib || exit $?
        run_subcmd "$@" || exit $?
      ;;

    * )
        error "not a frontend for $base ($scriptname)" 1
      ;;

  esac
}

# FIXME: Pre-bootstrap init
topics_init()
{
  # XXX test -n "$SCRIPTPATH" , does $0 in init.sh alway work?
  test -n "$scriptpath"
  export SCRIPTPATH=$scriptpath
  . $scriptpath/util.sh load-ext
  util_init
  . $scriptpath/match.lib.sh
  . $scriptpath/box.init.sh
  box_run_sh_test
  #. $scriptpath/htd.lib.sh
  lib_load main meta box date doc table remote
  # -- topics box init sentinel --
}

# FIXME: 2nd boostrap init
topics_lib()
{
  local __load_lib=1
  . $scriptpath/match.sh load-ext
  # -- topics box lib sentinel --
  set --
}


### Subcmd init, deinit

# Pre-exec: post subcmd-boostrap init
topics_load()
{
  # -- topics box lib sentinel --
  set --
}

# Post-exec: subcmd and script deinit
topics_unload()
{
  local unload_ret=0

  for x in $(try_value "${subcmd}" "" run | sed 's/./&\ /g')
  do case "$x" in
      y )
          test -z "$sock" || {
            topics_meta_bg_teardown
            unset bgd sock
          }
        ;;
      f )
          clean_failed || unload_ret=1
        ;;
  esac; done

  unset subcmd subcmd_pref \
          topics_default def_subcmd func_exists func \
          failed topics_session_id

  return $unload_ret
}



# Main entry - bootstrap script if requested
# Use hyphen to ignore source exec in login shell
case "$0" in "" ) ;; "-"* ) ;; * )

  # Ignore 'load-ext' sub-command
  # NOTE: arguments to source are working on Darwin 10.8.5, not Linux?
  # fix using another mechanism:
  # XXX: cleanup test -z "$__load_lib" || set -- "load-ext"
  case "$1" in load-ext ) ;; * )
      topics_main "$@" ;;

  esac ;;
esac

# Id: script-mpe/0.0.3-dev topics.sh
