#!/bin/sh

tags_src=$_
test -z "$__load_lib" || set -- "load-ext"

set -e



version=0.0.4-dev # script-mpe


# Script subcmd's funcs and vars

# See $scriptname help to get started

tags__stats()
{
  db_sa.py stats tag
}


tags__info()
{
  tag.py info
}


tags__list()
{
  tag.py list
}


tags__tags()
{
  test -n "$1" || set -- "*"
  tags.py find "$1"
}


tags__save_tags()
{
  set -- $@
  while test -n "$1"
  do
    tags.py get "$1" || tags.py insert "$1"
    shift 1
  done
}



# Generic subcmd's

tags_man_1__help="Usage help. "
tags_spc__help="-h|help"
tags__help()
{
  test -z "$dry_run" || note " ** DRY-RUN ** " 0
  choice_global=1 std__help "$@"
}
tags_als___h=help


tags_man_1__version="Version info"
tags__version()
{
  echo "script-mpe:$scriptname/$version"
}
tags_als__V=version


tags__edit()
{
  $EDITOR $0 $(which $base.py) "$@"
}
tags_als___e=edit




# Script main functions

tags_main()
{
  local
      scriptname=tags \
      base=$(basename $0 .sh) \
      scriptpath="$(cd "$(dirname "$0")"; pwd -P)" \
      failed=
  test -n "$verbosity" || verbosity=5

  tags_init || exit $?

  case "$base" in

    $scriptname )

        test -n "$1" || set -- list

        tags_lib || exit $?
        run_subcmd "$@" || exit $?
      ;;

    * )
        error "not a frontend for $base ($scriptname)" 1
      ;;

  esac
}

# FIXME: Pre-bootstrap init
tags_init()
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
  # -- tags box init sentinel --
}

# FIXME: 2nd boostrap init
tags_lib()
{
  local __load_lib=1
  . $scriptpath/match.sh load-ext
  # -- tags box lib sentinel --
  set --
}


### Subcmd init, deinit

# Pre-exec: post subcmd-boostrap init
tags_load()
{
  # -- tags box lib sentinel --
  set --
}

# Post-exec: subcmd and script deinit
tags_unload()
{
  local unload_ret=0

  for x in $(try_value "${subcmd}" "" run | sed 's/./&\ /g')
  do case "$x" in
      f )
          clean_failed || unload_ret=1
        ;;
  esac; done

  unset subcmd subcmd_pref \
          tags_default def_subcmd func_exists func \
          failed tags_session_id

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
      tags_main "$@" ;;

  esac ;;
esac

# Id: script-mpe/0.0.4-dev tags.sh
